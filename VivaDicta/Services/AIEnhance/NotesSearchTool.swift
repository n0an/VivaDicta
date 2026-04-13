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

/// Apple FM tool that searches the user's notes outside the current chat context.
///
/// Use this in single-note and multi-note chats when the user asks whether they
/// mentioned something elsewhere in their notes. The current note or notes are
/// already in the conversation, so this tool searches other notes only.
@available(iOS 26, *)
struct NotesSearchTool: Tool {
    let name = "searchNotes"
    let description = "Search the user's other notes when they ask whether they mentioned something elsewhere in their notes, or ask to find related notes. The current note or notes are already in the conversation, so use this tool to search other notes. Prefer this tool over web search for the user's personal notes."

    private let excludedTranscriptionIDs: Set<UUID>

    init(excludedTranscriptionIDs: Set<UUID>) {
        self.excludedTranscriptionIDs = excludedTranscriptionIDs
    }

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "The note search query, such as 'chess', 'burnout', or 'did I mention castling'")
        var query: String
    }

    func call(arguments: Arguments) async throws -> some PromptRepresentable {
        let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return NotesSearchToolRuntime.formatError("Notes search query cannot be empty.")
        }

        return await NotesSearchToolRuntime.searchNotes(
            query: query,
            excluding: excludedTranscriptionIDs
        )
    }
}

@available(iOS 26, *)
@MainActor
enum NotesSearchToolRuntime {
    static var modelContainer: ModelContainer?

    private static let logger = Logger(category: .chatViewModel)
    private static let maxResults = 4

    private enum MatchSource: String {
        case semantic
        case keyword
    }

    private struct NoteSearchHit {
        let transcription: Transcription
        var excerpt: String
        var sources: Set<MatchSource>
        var semanticScore: Float?
    }

    static func searchNotes(query: String, excluding excludedIDs: Set<UUID>) async -> GeneratedContent {
        guard let modelContainer else {
            return formatError("Notes search is unavailable because the note database is not configured.")
        }

        let modelContext = modelContainer.mainContext

        do {
            let allNotes = try modelContext.fetch(
                FetchDescriptor<Transcription>(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            )
            let noteMap = Dictionary(uniqueKeysWithValues: allNotes.map { ($0.id, $0) })

            var hitsByID: [UUID: NoteSearchHit] = [:]

            if SmartSearchFeature.isEnabled {
                let ragResults = try await RAGIndexingService.shared.search(query: query, topK: maxResults * 2)
                logger.logInfo("NotesSearchTool semantic search query='\(query)' hits=\(ragResults.count)")

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
                logger.logInfo("NotesSearchTool semantic search skipped because Smart Search is disabled")
            }

            let keywordMatches = try keywordMatches(
                query: query,
                modelContext: modelContext,
                allNotes: allNotes
            )
            logger.logInfo("NotesSearchTool keyword search query='\(query)' hits=\(keywordMatches.count)")

            for transcription in keywordMatches where !excludedIDs.contains(transcription.id) {
                let keywordExcerpt = keywordExcerpt(for: transcription, query: query)

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
                return GeneratedContent(properties: [
                    "status": "empty",
                    "summary": "No matching notes found outside the note or notes already in the conversation."
                ])
            }

            let summary = finalHits.enumerated().map { index, hit in
                let date = hit.transcription.timestamp.formatted(date: .abbreviated, time: .shortened)
                let title = noteTitle(for: hit.transcription)
                let sourceLabel = hit.sources
                    .map(\.rawValue)
                    .sorted()
                    .joined(separator: " + ")
                let scoreLabel = hit.semanticScore.map {
                    " score=\(Double($0).formatted(.number.precision(.fractionLength(3))))"
                } ?? ""

                return """
                \(index + 1). \(date) - \(title)
                Match: \(sourceLabel)\(scoreLabel)
                Excerpt: \(hit.excerpt)
                """
            }
            .joined(separator: "\n\n")

            return GeneratedContent(properties: [
                "status": "success",
                "summary": summary
            ])
        } catch {
            logger.logError("NotesSearchTool failed query='\(query)': \(error.localizedDescription)")
            return formatError("Notes search failed: \(error.localizedDescription)")
        }
    }

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
