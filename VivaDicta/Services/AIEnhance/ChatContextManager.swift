//
//  ChatContextManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation

/// Manages context window for "Chat with Note" conversations.
///
/// Handles token estimation, per-provider context limits, message trimming,
/// and conversation compaction (summarization of older messages).
struct ChatContextManager {

    // MARK: - System Prompt

    static let chatSystemPrompt = """
    You are a helpful AI assistant. The user is discussing a voice transcription note with you.
    The note text is provided in the first message wrapped in <NOTE> tags.

    Guidelines:
    - Answer questions about the note's content accurately
    - Help with summaries, action items, analysis, editing suggestions, translations
    - If asked about something not in the note, say so clearly
    - Keep responses concise unless the user asks for detail
    - Do not use long em-dashes; use normal hyphens instead
    """

    static let compactionPrompt = """
    Summarize the following conversation preserving key facts, decisions, and context. \
    Be concise. Cover the entire conversation from beginning to end, not just the end.
    """

    // MARK: - Token Estimation

    /// Estimates token count for a text string.
    /// Uses ~4 chars per token for Latin text, ~2 for CJK.
    static func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var latinChars = 0
        var cjkChars = 0

        for scalar in text.unicodeScalars {
            let value = scalar.value
            // CJK Unified Ideographs, Hiragana, Katakana, Hangul
            if (0x4E00...0x9FFF).contains(value) ||
               (0x3040...0x309F).contains(value) ||
               (0x30A0...0x30FF).contains(value) ||
               (0xAC00...0xD7AF).contains(value) {
                cjkChars += 1
            } else {
                latinChars += 1
            }
        }

        return (latinChars + 3) / 4 + (cjkChars + 1) / 2
    }

    // MARK: - Context Limits

    /// Known context window sizes per provider/model prefix.
    /// Returns token limit for the given provider and model.
    static func contextLimit(for provider: AIProvider, model: String) -> Int {
        let modelLower = model.lowercased()

        switch provider {
        case .apple:
            return 4_096

        case .anthropic:
            return 200_000

        case .openAI:
            if modelLower.hasPrefix("gpt-5") || modelLower.hasPrefix("gpt-4o") || modelLower.hasPrefix("o4") || modelLower.hasPrefix("o3") {
                return 128_000
            }
            return 128_000

        case .gemini:
            if modelLower.contains("2.5") || modelLower.contains("3.") {
                return 1_000_000
            }
            return 128_000

        case .groq:
            if modelLower.contains("llama-4") {
                return 128_000
            }
            return 8_192

        case .mistral:
            return 128_000

        case .grok:
            return 128_000

        case .ollama:
            return 4_096

        case .openRouter, .vercelAIGateway, .huggingFace:
            return 32_000

        default:
            return 8_000
        }
    }

    // MARK: - Context Fill Ratio

    /// Computes the context fill ratio (0.0-1.0) for the current conversation state.
    static func fillRatio(
        noteText: String,
        messages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> Double {
        let limit = contextLimit(for: provider, model: model)
        guard limit > 0 else { return 1.0 }

        let systemTokens = estimateTokens(chatSystemPrompt)
        let noteTokens = estimateTokens(noteText)
        let messageTokens = messages.reduce(0) { $0 + $1.estimatedTokenCount }
        let total = systemTokens + noteTokens + messageTokens

        return min(Double(total) / Double(limit), 1.0)
    }

    /// Whether auto-compaction should trigger (fill > 70%).
    static func shouldAutoCompact(
        noteText: String,
        messages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> Bool {
        fillRatio(noteText: noteText, messages: messages, provider: provider, model: model) > 0.7
    }

    // MARK: - Message Assembly

    /// Builds the messages array for the AI API call, applying context trimming if needed.
    ///
    /// Returns: `(systemMessage, messages)` where messages is an array of role/content pairs.
    static func assembleMessages(
        noteText: String,
        chatMessages: [ChatMessage],
        provider: AIProvider,
        model: String
    ) -> (systemMessage: String, messages: [[String: String]]) {
        let limit = contextLimit(for: provider, model: model)
        let responseReserve = min(4_096, limit / 4)
        let systemTokens = estimateTokens(chatSystemPrompt)

        // Note text - truncate if > 50% of context
        let noteTokens = estimateTokens(noteText)
        let maxNoteTokens = limit / 2
        let effectiveNoteText: String
        if noteTokens > maxNoteTokens {
            // Rough character-based truncation
            let maxChars = maxNoteTokens * 4
            effectiveNoteText = String(noteText.prefix(maxChars)) + "\n\n[... note truncated due to length ...]"
        } else {
            effectiveNoteText = noteText
        }
        let effectiveNoteTokens = estimateTokens(effectiveNoteText)

        let fixedOverhead = systemTokens + effectiveNoteTokens
        let availableForChat = max(0, limit - fixedOverhead - responseReserve)

        // Build note context as first user message
        let noteMessage: [String: String] = [
            "role": "user",
            "content": "<NOTE>\n\(effectiveNoteText)\n</NOTE>"
        ]
        let noteMessageTokens = estimateTokens(noteMessage["content"]!)

        // Trim chat messages (newest first, keep what fits)
        let sorted = chatMessages.sorted { $0.createdAt < $1.createdAt }
        var selectedMessages: [[String: String]] = []
        var usedTokens = noteMessageTokens

        // Walk from newest to oldest
        for message in sorted.reversed() {
            let tokens = message.estimatedTokenCount > 0
                ? message.estimatedTokenCount
                : estimateTokens(message.content)

            if usedTokens + tokens > availableForChat, !selectedMessages.isEmpty {
                break
            }
            selectedMessages.insert(
                ["role": message.isSummary ? "user" : message.role, "content": message.content],
                at: 0
            )
            usedTokens += tokens
        }

        // Assemble: note context + selected chat messages
        var allMessages = [noteMessage]
        allMessages.append(contentsOf: selectedMessages)

        return (chatSystemPrompt, allMessages)
    }

    // MARK: - Compaction

    /// Identifies messages to compact (all except the most recent `keepCount`).
    /// Returns nil if there aren't enough messages to compact.
    static func messagesToCompact(
        from messages: [ChatMessage],
        keepCount: Int = 4
    ) -> (toCompact: [ChatMessage], toKeep: [ChatMessage])? {
        let sorted = messages
            .filter { !$0.isSummary }
            .sorted { $0.createdAt < $1.createdAt }

        guard sorted.count > keepCount else { return nil }

        let splitIndex = sorted.count - keepCount
        let toCompact = Array(sorted.prefix(splitIndex))
        let toKeep = Array(sorted.suffix(keepCount))

        return (toCompact, toKeep)
    }

    /// Formats messages into a conversation transcript for summarization.
    static func formatForCompaction(_ messages: [ChatMessage]) -> String {
        messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { msg in
                let role = msg.role == "assistant" ? "Assistant" : "User"
                return "\(role): \(msg.content)"
            }
            .joined(separator: "\n\n")
    }
}
