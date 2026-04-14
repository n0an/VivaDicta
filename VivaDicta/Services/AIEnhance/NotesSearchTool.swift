//
//  NotesSearchTool.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation
import FoundationModels
import SwiftData
import os

enum CrossNoteSearchStatus: String, Sendable {
    case success
    case empty
    case error
}

enum CrossNoteSearchMatchSource: String, Sendable {
    case semantic
    case keyword
}

struct CrossNoteSearchResult: Sendable {
    let transcriptionId: UUID
    let title: String
    let date: String
    let excerpt: String
    let sources: [CrossNoteSearchMatchSource]
    let relevanceScore: Float?
}

struct CrossNoteSearchPayload: Sendable {
    let query: String
    let status: CrossNoteSearchStatus
    let results: [CrossNoteSearchResult]
    let message: String?

    var sourceIDs: [UUID] {
        results.map(\.transcriptionId)
    }

    var sourceCitations: [SmartSearchSourceCitation] {
        results.map { result in
            SmartSearchSourceCitation(
                transcriptionId: result.transcriptionId,
                excerpt: result.excerpt,
                relevanceScore: result.relevanceScore ?? 0
            )
        }
    }
}

/// Apple FM tool that searches the user's notes outside the current chat context.
///
/// Parked for future use.
/// This tool is intentionally not attached to Apple FM chat sessions right now
/// because the model invoked it too eagerly for current-note questions like
/// summaries, insights, and "what is this note about?", which degraded answers.
/// The current note or notes are already in the conversation, so this tool should
/// only return when we have a cleaner way to restrict it to true cross-note intent.
@available(iOS 26, *)
struct NotesSearchTool: Tool {
    let name = "searchOtherNotes"
    let description = "Search the user's OTHER notes ONLY when the user explicitly asks whether they mentioned something elsewhere in their notes, asks to search other notes, or asks to find related notes beyond the current note or notes already in the conversation. Do NOT use this tool for summarizing, explaining, extracting insights from, or answering questions about the current note or notes already in the conversation. Prefer this tool over web search for the user's personal notes."

    private let excludedTranscriptionIDs: Set<UUID>
    private let captureID: UUID

    init(excludedTranscriptionIDs: Set<UUID>, captureID: UUID) {
        self.excludedTranscriptionIDs = excludedTranscriptionIDs
        self.captureID = captureID
    }

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "A short topic or phrase to search for in the user's other notes, such as 'chess', 'burnout', or 'castling'")
        var query: String
    }

    func call(arguments: Arguments) async throws -> some PromptRepresentable {
        let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return NotesSearchToolRuntime.formatError("Notes search query cannot be empty.")
        }

        let payload = await NotesSearchToolRuntime.searchNotesPayload(
            query: query,
            excluding: excludedTranscriptionIDs
        )
        await NotesSearchToolRuntime.capture(payload.sourceCitations, for: captureID)
        return await NotesSearchToolRuntime.formatGeneratedContent(from: payload)
    }
}

@MainActor
enum NotesSearchToolRuntime {
    static var modelContainer: ModelContainer?
    private static var capturedCitationsByID: [UUID: [UUID: SmartSearchSourceCitation]] = [:]
    private static let maxResults = 4
    private static let logger = Logger(category: .ragSearch)

    private struct NoteSearchHit {
        let transcription: Transcription
        var excerpt: String
        var sources: Set<CrossNoteSearchMatchSource>
        var semanticScore: Float?
    }

    static func beginCapture(for captureID: UUID) {
        capturedCitationsByID[captureID] = [:]
    }

    static func consumeCapturedCitations(for captureID: UUID) -> [SmartSearchSourceCitation] {
        let citations = capturedCitationsByID.removeValue(forKey: captureID).map { Array($0.values) } ?? []
        return citations.sorted { lhs, rhs in
            if lhs.relevanceScore != rhs.relevanceScore {
                return lhs.relevanceScore > rhs.relevanceScore
            }
            return lhs.transcriptionId.uuidString < rhs.transcriptionId.uuidString
        }
    }

    static func searchNotesPayload(
        query: String,
        excluding excludedIDs: Set<UUID>
    ) async -> CrossNoteSearchPayload {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return CrossNoteSearchPayload(
                query: trimmedQuery,
                status: .error,
                results: [],
                message: "Notes search query cannot be empty."
            )
        }

        guard let modelContainer else {
            return CrossNoteSearchPayload(
                query: trimmedQuery,
                status: .error,
                results: [],
                message: "Notes search is unavailable because the note database is not configured."
            )
        }

        let modelContext = modelContainer.mainContext

        do {
            logger.logInfo(
                "Cross-note search start query='\(trimmedQuery)' excludedNotes=\(excludedIDs.count) smartEnabled=\(SmartSearchFeature.isEnabled)"
            )
            let allNotes = try modelContext.fetch(
                FetchDescriptor<Transcription>(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            )
            logger.logInfo("Cross-note search loaded allNotes=\(allNotes.count)")
            let noteMap = Dictionary(uniqueKeysWithValues: allNotes.map { ($0.id, $0) })

            var hitsByID: [UUID: NoteSearchHit] = [:]

            if SmartSearchFeature.isEnabled {
                let ragResults = try await RAGIndexingService.shared.search(query: trimmedQuery, topK: maxResults * 2)
                logger.logInfo("Cross-note search semantic hits=\(ragResults.count)")

                for result in ragResults where !excludedIDs.contains(result.transcriptionId) {
                    guard let transcription = noteMap[result.transcriptionId] else { continue }

                    hitsByID[result.transcriptionId] = NoteSearchHit(
                        transcription: transcription,
                        excerpt: excerptPreview(result.chunkText),
                        sources: [.semantic],
                        semanticScore: result.relevanceScore
                    )
                }
            } else {
                logger.logInfo("Cross-note search semantic step skipped because Smart Search is disabled")
            }

            let keywordMatches = try keywordMatches(
                query: trimmedQuery,
                modelContext: modelContext,
                allNotes: allNotes
            )
            logger.logInfo("Cross-note search keyword hits=\(keywordMatches.count)")

            for transcription in keywordMatches where !excludedIDs.contains(transcription.id) {
                let keywordExcerpt = keywordExcerpt(for: transcription, query: trimmedQuery)

                if var existing = hitsByID[transcription.id] {
                    existing.sources.insert(.keyword)
                    if existing.semanticScore == nil {
                        existing.excerpt = keywordExcerpt
                    }
                    hitsByID[transcription.id] = existing
                } else {
                    hitsByID[transcription.id] = NoteSearchHit(
                        transcription: transcription,
                        excerpt: keywordExcerpt,
                        sources: [.keyword],
                        semanticScore: nil
                    )
                }
            }

            let finalHits = hitsByID.values
                .sorted(by: isPreferred(_:over:))
                .prefix(maxResults)

            guard !finalHits.isEmpty else {
                logger.logInfo("Cross-note search returned 0 final hits")
                return CrossNoteSearchPayload(
                    query: trimmedQuery,
                    status: .empty,
                    results: [],
                    message: "No matching notes found outside the note or notes already in the conversation."
                )
            }

            let results = finalHits.map { hit in
                CrossNoteSearchResult(
                    transcriptionId: hit.transcription.id,
                    title: noteTitle(for: hit.transcription),
                    date: hit.transcription.timestamp.formatted(date: .abbreviated, time: .shortened),
                    excerpt: hit.excerpt,
                    sources: hit.sources.sorted { $0.rawValue < $1.rawValue },
                    relevanceScore: hit.semanticScore
                )
            }
            let sourceSummary = results
                .map { $0.sources.map(\.rawValue).joined(separator: "+") }
                .joined(separator: ",")

            logger.logInfo(
                "Cross-note search final hits=\(results.count) sources=\(sourceSummary)"
            )

            return CrossNoteSearchPayload(
                query: trimmedQuery,
                status: .success,
                results: results,
                message: nil
            )
        } catch {
            logger.logError("Cross-note search failed: \(error.localizedDescription)")
            return CrossNoteSearchPayload(
                query: trimmedQuery,
                status: .error,
                results: [],
                message: "Notes search failed: \(error.localizedDescription)"
            )
        }
    }

    @available(iOS 26, *)
    static func formatGeneratedContent(from payload: CrossNoteSearchPayload) -> GeneratedContent {
        switch payload.status {
        case .success:
            let summary = payload.results.enumerated().map { index, hit in
                let sourceLabel = hit.sources
                    .map(\.rawValue)
                    .joined(separator: " + ")
                let scoreLabel = hit.relevanceScore.map {
                    " score=\(Double($0).formatted(.number.precision(.fractionLength(3))))"
                } ?? ""

                return """
                \(index + 1). \(hit.date) - \(hit.title)
                Match: \(sourceLabel)\(scoreLabel)
                Excerpt: \(hit.excerpt)
                """
            }
            .joined(separator: "\n\n")

            return GeneratedContent(properties: [
                "status": CrossNoteSearchStatus.success.rawValue,
                "summary": summary
            ])
        case .empty, .error:
            return GeneratedContent(properties: [
                "status": payload.status.rawValue,
                "summary": payload.message ?? "Unknown notes search result."
            ])
        }
    }

    @available(iOS 26, *)
    nonisolated static func formatError(_ message: String) -> GeneratedContent {
        GeneratedContent(properties: [
            "status": "error",
            "summary": message
        ])
    }

    private static func keywordMatches(
        query: String,
        modelContext: ModelContext,
        allNotes: [Transcription]
    ) throws -> [Transcription] {
        var directDescriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        directDescriptor.predicate = #Predicate<Transcription> { transcription in
            transcription.text.localizedStandardContains(query) ||
                (transcription.enhancedText?.localizedStandardContains(query) ?? false)
        }

        let directMatches = try modelContext.fetch(directDescriptor)

        let variationDescriptor = FetchDescriptor<TranscriptionVariation>(
            predicate: #Predicate { $0.text.localizedStandardContains(query) }
        )
        let variationMatches = try modelContext.fetch(variationDescriptor)

        let directIDs = Set(directMatches.map(\.id))
        let variationIDs = Set(variationMatches.compactMap { $0.transcription?.id })
        let additionalIDs = variationIDs.subtracting(directIDs)

        let additionalMatches = allNotes.filter { additionalIDs.contains($0.id) }
        return (directMatches + additionalMatches)
            .sorted { $0.timestamp > $1.timestamp }
    }

    private static func keywordExcerpt(for transcription: Transcription, query: String) -> String {
        if let excerpt = matchingExcerpt(in: transcription.text, query: query) {
            return excerpt
        }

        if let enhancedText = transcription.enhancedText,
           let excerpt = matchingExcerpt(in: enhancedText, query: query) {
            return excerpt
        }

        for variation in (transcription.variations ?? []).sorted(by: { $0.createdAt > $1.createdAt }) {
            if let excerpt = matchingExcerpt(in: variation.text, query: query) {
                return excerpt
            }
        }

        return excerptPreview(transcription.text)
    }

    private static func matchingExcerpt(in text: String, query: String) -> String? {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return nil }

        let lowerText = text.lowercased()
        let lowerQuery = normalizedQuery.lowercased()
        guard let range = lowerText.range(of: lowerQuery) else { return nil }

        let start = text.distance(from: text.startIndex, to: range.lowerBound)
        let end = text.distance(from: text.startIndex, to: range.upperBound)
        let snippetStart = max(0, start - 80)
        let snippetEnd = min(text.count, end + 80)

        let startIndex = text.index(text.startIndex, offsetBy: snippetStart)
        let endIndex = text.index(text.startIndex, offsetBy: snippetEnd)
        return excerptPreview(String(text[startIndex..<endIndex]))
    }

    private static func excerptPreview(_ text: String) -> String {
        let flattened = text
            .replacing("\n", with: " ")
            .replacing("\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard flattened.count > 180 else { return flattened }
        return String(flattened.prefix(180)) + "..."
    }

    private static func noteTitle(for transcription: Transcription) -> String {
        let source = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = source.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = firstLine.map { String($0.prefix(50)) } ?? "Note"
        return title.isEmpty ? "Note" : title
    }

    static func capture(_ citations: [SmartSearchSourceCitation], for captureID: UUID) {
        var captured = capturedCitationsByID[captureID, default: [:]]

        for citation in citations {
            if let existing = captured[citation.transcriptionId] {
                if citation.relevanceScore > existing.relevanceScore {
                    captured[citation.transcriptionId] = citation
                }
            } else {
                captured[citation.transcriptionId] = citation
            }
        }

        capturedCitationsByID[captureID] = captured
    }

    private static func isPreferred(_ lhs: NoteSearchHit, over rhs: NoteSearchHit) -> Bool {
        switch (lhs.semanticScore, rhs.semanticScore) {
        case (_?, _?) where lhs.sources.contains(.keyword) != rhs.sources.contains(.keyword):
            return lhs.sources.contains(.keyword)
        case let (left?, right?) where left != right:
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.transcription.timestamp > rhs.transcription.timestamp
        }
    }
}
