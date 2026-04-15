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
/// This tool is attached only when the global experimental setting for automatic
/// cross-note search is enabled. It is still kept off by default because weaker
/// models may invoke it too eagerly for current-note questions.
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

        await NotesSearchToolRuntime.markInvoked(for: captureID)
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
    private static var invokedCaptureIDs: Set<UUID> = []
    private static let maxResults = 4
    private static let logger = Logger(category: .ragSearch)

    static func beginCapture(for captureID: UUID) {
        capturedCitationsByID[captureID] = [:]
        invokedCaptureIDs.remove(captureID)
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

    static func consumeDidInvoke(for captureID: UUID) -> Bool {
        invokedCaptureIDs.remove(captureID) != nil
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

        guard SmartSearchFeature.isEnabled else {
            logger.logInfo("Cross-note search skipped because Smart Search is disabled")
            return CrossNoteSearchPayload(
                query: trimmedQuery,
                status: .error,
                results: [],
                message: "Other-note search is unavailable because Smart Search is disabled."
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

            let ragResults = try await RAGIndexingService.shared.search(query: trimmedQuery, topK: maxResults * 2)
            logger.logInfo("Cross-note search semantic hits=\(ragResults.count)")

            guard !ragResults.isEmpty else {
                logger.logInfo("Cross-note search returned 0 final hits")
                return CrossNoteSearchPayload(
                    query: trimmedQuery,
                    status: .empty,
                    results: [],
                    message: "No matching notes found outside the note or notes already in the conversation."
                )
            }

            let finalResults: [CrossNoteSearchResult] = Array(
                ragResults
                    .filter { !excludedIDs.contains($0.transcriptionId) }
                    .compactMap { result -> CrossNoteSearchResult? in
                    guard let transcription = resolveTranscription(id: result.transcriptionId, in: modelContext) else {
                        logger.logWarning(
                            "Cross-note search could not resolve transcription id=\(result.transcriptionId.uuidString)"
                        )
                        return nil
                    }

                    return CrossNoteSearchResult(
                        transcriptionId: transcription.id,
                        title: noteTitle(for: transcription),
                        date: transcription.timestamp.formatted(date: .abbreviated, time: .shortened),
                        excerpt: excerptPreview(result.chunkText),
                        sources: [.semantic],
                        relevanceScore: result.relevanceScore
                    )
                }
                .prefix(maxResults)
            )

            guard !finalResults.isEmpty else {
                logger.logInfo("Cross-note search returned 0 final hits after exclusions or missing notes")
                return CrossNoteSearchPayload(
                    query: trimmedQuery,
                    status: .empty,
                    results: [],
                    message: "No matching notes found outside the note or notes already in the conversation."
                )
            }

            let results = finalResults
            let sourceSummary = results
                .map { result in
                    result.sources.map { $0.rawValue }.joined(separator: "+")
                }
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

    private static func resolveTranscription(id: UUID, in modelContext: ModelContext) -> Transcription? {
        let descriptor = FetchDescriptor<Transcription>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
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

    static func markInvoked(for captureID: UUID) {
        invokedCaptureIDs.insert(captureID)
    }
}
