//
//  MultiNoteContextManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import FoundationModels

/// Manages context window for multi-note chat conversations.
///
/// Parallel to ``ChatContextManager`` but specialized for multiple source notes.
/// Wraps each note in XML `<NOTE>` tags for AI disambiguation and handles
/// proportional truncation when combined notes exceed context limits.
struct MultiNoteContextManager {

    // MARK: - System Prompt

    static let systemPrompt = """
    You are a helpful AI assistant. The user is discussing multiple voice transcription notes with you.
    Each note is provided in a separate <NOTE> block with an id and title attribute.

    Guidelines:
    - Answer questions about the notes' content accurately
    - When referencing a specific note, mention its title or number
    - Help with cross-note analysis, comparisons, summaries, action items
    - If asked about something not in any note, say so clearly
    - Keep responses concise unless the user asks for detail
    - Do not use long em-dashes; use normal hyphens instead
    """

    // MARK: - Note Assembly

    /// Wraps multiple notes in XML tags for AI disambiguation.
    static func assembleNoteText(from sources: [MultiNoteSource]) -> String {
        var parts: [String] = []

        for (index, source) in sources.enumerated() {
            guard let transcription = source.transcription else { continue }
            let noteText = transcription.enhancedText ?? transcription.text
            let firstLine = noteText.prefix(60).components(separatedBy: .newlines).first ?? "Note \(index + 1)"
            parts.append("<NOTE id=\"\(index + 1)\" title=\"\(firstLine)\">\n\(noteText)\n</NOTE>")
        }

        return parts.joined(separator: "\n\n")
    }

    /// Estimated token count for assembled note text.
    static func noteTokenCount(from sources: [MultiNoteSource]) -> Int {
        ChatContextManager.estimateTokens(assembleNoteText(from: sources))
    }

    // MARK: - Truncation

    /// Proportionally truncates notes when they exceed context budget.
    static func truncateNotesIfNeeded(
        sources: [MultiNoteSource],
        provider: AIProvider,
        model: String
    ) -> String {
        let limit = ChatContextManager.contextLimit(for: provider, model: model)
        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
        let responseReserve = min(4_096, limit / 4)
        let maxNoteTokens = limit - systemTokens - responseReserve

        let fullText = assembleNoteText(from: sources)
        let fullTokens = ChatContextManager.estimateTokens(fullText)

        guard fullTokens > maxNoteTokens else { return fullText }

        let activeSources = sources.filter { $0.transcription != nil }
        let perNoteChars = (maxNoteTokens * 4) / max(activeSources.count, 1)

        var parts: [String] = []
        for (index, source) in activeSources.enumerated() {
            guard let transcription = source.transcription else { continue }
            let noteText = transcription.enhancedText ?? transcription.text
            let firstLine = noteText.prefix(60).components(separatedBy: .newlines).first ?? "Note \(index + 1)"
            let truncated = String(noteText.prefix(perNoteChars))
            let suffix = truncated.count < noteText.count ? "\n[... truncated ...]" : ""
            parts.append("<NOTE id=\"\(index + 1)\" title=\"\(firstLine)\">\n\(truncated)\(suffix)\n</NOTE>")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Context Fill Ratio

    static func fillRatio(
        noteText: String,
        messages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> Double {
        let limit = ChatContextManager.contextLimit(for: provider, model: model)
        guard limit > 0 else { return 1.0 }

        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
        let noteTokens = ChatContextManager.estimateTokens(noteText)
        let messageTokens = messages.reduce(0) { $0 + $1.estimatedTokenCount }
        let total = systemTokens + noteTokens + messageTokens

        return min(Double(total) / Double(limit), 1.0)
    }

    static func shouldAutoCompact(
        noteText: String,
        messages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> Bool {
        fillRatio(noteText: noteText, messages: messages, provider: provider, model: model) > 0.7
    }

    // MARK: - Message Assembly

    /// Builds the messages array for cloud AI API calls.
    static func assembleMessages(
        noteText: String,
        chatMessages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> (systemMessage: String, messages: [[String: String]]) {
        let limit = ChatContextManager.contextLimit(for: provider, model: model)
        let responseReserve = min(4_096, limit / 4)
        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
        let noteTokens = ChatContextManager.estimateTokens(noteText)

        let fixedOverhead = systemTokens + noteTokens
        let availableForChat = max(0, limit - fixedOverhead - responseReserve)

        let noteMessage: [String: String] = ["role": "user", "content": noteText]
        let noteMessageTokens = ChatContextManager.estimateTokens(noteText)

        let sorted = chatMessages.sorted { $0.createdAt < $1.createdAt }
        var selectedMessages: [[String: String]] = []
        var usedTokens = noteMessageTokens

        for message in sorted.reversed() {
            let tokens = message.estimatedTokenCount > 0
                ? message.estimatedTokenCount
                : ChatContextManager.estimateTokens(message.content)
            if usedTokens + tokens > availableForChat, !selectedMessages.isEmpty { break }
            selectedMessages.insert(
                ["role": message.isSummary ? "user" : message.role, "content": message.content],
                at: 0
            )
            usedTokens += tokens
        }

        var allMessages = [noteMessage]
        allMessages.append(contentsOf: selectedMessages)

        return (systemPrompt, allMessages)
    }
}
