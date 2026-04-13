//
//  SmartSearchContextManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import Foundation
import FoundationModels
import os

/// Manages context assembly for RAG-powered Smart Search conversations.
///
/// Unlike ``MultiNoteContextManager`` where note context is fixed at creation time,
/// Smart Search retrieves relevant notes dynamically per message via vector search.
/// Each user message gets its own set of retrieved note chunks as context.
struct SmartSearchContextManager {
    private static let logger = Logger(category: .smartSearchChat)
    private static let previewCharacterLimit = 220

    // MARK: - System Prompt

    static let systemPrompt = """
    You are a helpful AI assistant with access to the user's voice transcription notes.
    Relevant note excerpts are retrieved automatically for each question and provided in source sections.

    Guidelines:
    - Answer questions using the provided note context
    - When referencing a specific note, mention its title or date
    - The provided source sections are excerpts, not always full notes
    - Never mention prompt structure, source numbering, or internal formatting in your answer
    - If the provided notes don't contain enough information to answer, say so clearly in plain natural language
    - You may combine information from multiple notes to form a complete answer
    - Keep responses concise unless the user asks for detail
    - Do not use long em-dashes; use normal hyphens instead
    - Do not fabricate information that isn't in the provided notes
    """

    // MARK: - Augmented Prompt Assembly

    /// Builds an augmented user prompt by prepending retrieved note context.
    ///
    /// Called per-message: the ViewModel performs RAG search, resolves source
    /// transcriptions, then calls this to wrap the retrieved excerpts in
    /// simple source sections before the user's actual question.
    ///
    /// - Parameters:
    ///   - query: The user's original question text.
    ///   - searchResults: RAG search results with chunk text and scores.
    ///   - transcriptions: Resolved Transcription objects matching the search results.
    /// - Returns: A single prompt string with note context + user question.
    static func assembleAugmentedPrompt(
        query: String,
        searchResults: [RAGSearchResult],
        transcriptions: [Transcription]
    ) -> String {
        guard !searchResults.isEmpty else {
            logger.logInfo("Smart Search prompt assembly skipped because retrieval returned 0 results")
            return query
        }

        logger.logInfo(
            "Smart Search prompt assembly started query='\(preview(query, limit: 80))' searchResults=\(searchResults.count) transcriptions=\(transcriptions.count)"
        )

        let transcriptionMap = Dictionary(
            uniqueKeysWithValues: transcriptions.map { ($0.id, $0) }
        )

        var noteParts: [String] = []

        for (index, result) in searchResults.enumerated() {
            guard let transcription = transcriptionMap[result.transcriptionId] else {
                continue
            }

            let excerpt = result.chunkText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !excerpt.isEmpty else {
                continue
            }

            let title = noteTitle(for: transcription, fallback: "Note \(index + 1)")
            let date = transcription.timestamp.formatted(date: .abbreviated, time: .shortened)

            logger.logInfo(
                "Smart Search prompt note[\(index + 1)] noteId=\(result.transcriptionId.uuidString) title='\(title)' date='\(date)' excerpt='\(preview(excerpt))'"
            )

            noteParts.append(
                """
                SOURCE \(index + 1)
                Title: \(title)
                Date: \(date)
                Excerpt:
                \(excerpt)
                """
            )
        }

        if noteParts.isEmpty {
            logger.logWarning("Smart Search prompt assembly produced 0 usable note blocks")
            return query
        }

        let context = noteParts.joined(separator: "\n\n")
        logger.logInfo("Smart Search prompt assembly complete noteBlocks=\(noteParts.count) contextChars=\(context.count)")
        return """
        Here are relevant excerpts from the user's notes:

        \(context)

        USER QUESTION:
        \(query)
        """
    }

    private static func noteTitle(for transcription: Transcription, fallback: String) -> String {
        let firstLine = transcription.text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = firstLine.map { String($0.prefix(60)) } ?? fallback
        return title.isEmpty ? fallback : title
    }

    private static func preview(_ text: String, limit: Int = previewCharacterLimit) -> String {
        let flattened = text
            .replacing("\n", with: " ")
            .replacing("\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard flattened.count > limit else { return flattened }
        return String(flattened.prefix(limit)) + "..."
    }

    // MARK: - Context Fill Ratio

    /// Estimates the context fill ratio for a Smart Search conversation.
    ///
    /// Since RAG context varies per message, this uses the most recent
    /// augmented prompt size as an approximation.
    static func fillRatio(
        messages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> Double {
        let limit = ChatContextManager.contextLimit(for: provider, model: model)
        guard limit > 0 else { return 1.0 }

        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
        let messageTokens = messages.reduce(0) { $0 + $1.estimatedTokenCount }
        let total = systemTokens + messageTokens

        return min(Double(total) / Double(limit), 1.0)
    }

    static func shouldAutoCompact(
        messages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> Bool {
        fillRatio(messages: messages, provider: provider, model: model) > 0.7
    }

    // MARK: - Message Assembly

    /// Builds the messages array for cloud AI API calls.
    ///
    /// Unlike multi-note chat, the augmented prompt (with RAG context) is already
    /// embedded in the most recent user message content. Older messages contain
    /// the original user text only.
    static func assembleMessages(
        chatMessages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> (systemMessage: String, messages: [[String: String]]) {
        let limit = ChatContextManager.contextLimit(for: provider, model: model)
        let responseReserve = min(4_096, limit / 4)
        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)

        let availableForChat = max(0, limit - systemTokens - responseReserve)

        let sorted = chatMessages.sorted { $0.createdAt < $1.createdAt }
        var selectedMessages: [[String: String]] = []
        var usedTokens = 0

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

        return (systemPrompt, selectedMessages)
    }
}
