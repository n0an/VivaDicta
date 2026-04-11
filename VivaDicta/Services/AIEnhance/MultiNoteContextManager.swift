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
/// Parallel to ``ChatContextManager`` but with a multi-note system prompt.
/// Note text is assembled once at conversation creation time and stored
/// in ``MultiNoteConversation.noteContext``.
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
    - ALWAYS answer from the notes in the conversation first. Only use web search when the user explicitly asks to look something up online or asks about current events, news, or real-time information not covered in the notes.
    """

    // MARK: - Note Assembly (used at creation time)

    /// Wraps multiple transcriptions in XML tags for AI disambiguation.
    /// Called once when creating a conversation; the result is stored in `noteContext`.
    static func assembleNoteText(from transcriptions: [Transcription]) -> String {
        var parts: [String] = []

        for (index, transcription) in transcriptions.enumerated() {
            let noteText = transcription.text
            let firstLine = noteText.prefix(60).components(separatedBy: .newlines).first ?? "Note \(index + 1)"
            let date = transcription.timestamp.formatted(date: .abbreviated, time: .shortened)
            parts.append("<NOTE id=\"\(index + 1)\" title=\"\(firstLine)\" date=\"\(date)\">\n\(noteText)\n</NOTE>")
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
