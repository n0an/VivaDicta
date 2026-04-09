//
//  ChatViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation
import SwiftData
import os

/// View model for the "Chat with Note" feature.
///
/// Manages message history, AI communication, provider/model selection,
/// and context window compaction for a single transcription's chat.
@Observable
@MainActor
final class ChatViewModel {
    private let logger = Logger(category: .chatViewModel)

    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingText: String = ""
    var errorMessage: String?
    var isCompacting: Bool = false

    // MARK: - Provider/Model

    var selectedProvider: AIProvider?
    var selectedModel: String?

    // MARK: - Context

    /// Approximate context fill ratio (0.0-1.0).
    var contextFillRatio: Double {
        guard let provider = selectedProvider, let model = selectedModel else { return 0 }
        return ChatContextManager.fillRatio(
            noteText: transcription.text,
            messages: messages,
            provider: provider,
            model: model
        )
    }

    // MARK: - Dependencies

    let transcription: Transcription
    private let aiService: AIService
    private let modelContext: ModelContext
    private var streamingTask: Task<Void, Never>?

    // MARK: - Init

    init(transcription: Transcription, aiService: AIService, modelContext: ModelContext) {
        self.transcription = transcription
        self.aiService = aiService
        self.modelContext = modelContext

        // Restore persisted provider/model or default to current mode
        if let providerName = transcription.chatAIProviderName,
           let provider = AIProvider(rawValue: providerName) {
            self.selectedProvider = provider
            self.selectedModel = transcription.chatAIModelName ?? provider.defaultModel
        } else if let modeProvider = aiService.selectedMode.aiProvider {
            self.selectedProvider = modeProvider
            self.selectedModel = aiService.selectedMode.aiModel
        }

        loadMessages()
    }

    // MARK: - Message Loading

    func loadMessages() {
        let sorted = (transcription.chatMessages ?? []).sorted { $0.createdAt < $1.createdAt }
        messages = sorted
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let provider = selectedProvider, let model = selectedModel else {
            errorMessage = "No AI provider selected"
            return
        }
        guard aiService.isChatProviderReady(provider) else {
            errorMessage = "\(provider.displayName) is not configured"
            return
        }

        inputText = ""
        errorMessage = nil

        // Create and persist user message
        let userMessage = ChatMessage(
            role: "user",
            content: text,
            estimatedTokenCount: ChatContextManager.estimateTokens(text)
        )
        userMessage.transcription = transcription
        modelContext.insert(userMessage)
        messages.append(userMessage)

        // Start streaming task
        isStreaming = true
        streamingText = ""

        streamingTask = Task {
            do {
                // Auto-compact if needed
                if ChatContextManager.shouldAutoCompact(
                    noteText: transcription.text,
                    messages: messages,
                    provider: provider,
                    model: model
                ) {
                    logger.logInfo("Chat - Auto-compacting context")
                    try await performCompaction()
                }

                // Assemble messages for API
                let (systemMessage, apiMessages) = ChatContextManager.assembleMessages(
                    noteText: transcription.text,
                    chatMessages: messages,
                    provider: provider,
                    model: model
                )

                // Make streaming request
                let result = try await aiService.makeChatStreamingRequest(
                    provider: provider,
                    model: model,
                    systemMessage: systemMessage,
                    messages: apiMessages,
                    onPartialResponse: { [weak self] partial in
                        self?.streamingText = partial
                    }
                )

                // Create assistant message
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: result,
                    aiProviderName: provider.rawValue,
                    aiModelName: model,
                    estimatedTokenCount: ChatContextManager.estimateTokens(result)
                )
                assistantMessage.transcription = transcription
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)

                HapticManager.success()

            } catch is CancellationError {
                // Save partial response if any
                savePartialResponse(provider: provider, model: model)
            } catch {
                logger.logError("Chat error: \(error.localizedDescription)")

                let errorContent = error.localizedDescription
                let errorMsg = ChatMessage(
                    role: "assistant",
                    content: errorContent,
                    aiProviderName: provider.rawValue,
                    aiModelName: model,
                    isError: true,
                    estimatedTokenCount: ChatContextManager.estimateTokens(errorContent)
                )
                errorMsg.transcription = transcription
                modelContext.insert(errorMsg)
                messages.append(errorMsg)

                HapticManager.error()
            }

            isStreaming = false
            streamingText = ""
            trySave()
        }
    }

    // MARK: - Cancel

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
    }

    // MARK: - Clear Chat

    func clearChat() {
        cancelStreaming()
        for message in messages {
            modelContext.delete(message)
        }
        messages.removeAll()
        trySave()
    }

    // MARK: - Compact Chat

    func compactChat() async {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard aiService.isChatProviderReady(provider) else { return }

        isCompacting = true
        do {
            try await performCompaction()
            HapticManager.success()
        } catch {
            logger.logError("Chat compaction failed: \(error.localizedDescription)")
            errorMessage = "Compaction failed: \(error.localizedDescription)"
        }
        isCompacting = false
    }

    // MARK: - Provider/Model Update

    func updateProvider(_ provider: AIProvider) {
        selectedProvider = provider
        selectedModel = provider.defaultModel
        persistProviderSelection()
    }

    func updateModel(_ model: String) {
        selectedModel = model
        persistProviderSelection()
    }

    // MARK: - Private Helpers

    private func performCompaction() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }

        let nonSummaryMessages = messages.filter { !$0.isSummary }
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages) else {
            return
        }

        let transcript = ChatContextManager.formatForCompaction(split.toCompact)

        // Use the same AI to summarize
        let summaryPrompt = ChatContextManager.compactionPrompt
        let summaryMessages: [[String: String]] = [
            ["role": "user", "content": "Summarize this conversation:\n\n\(transcript)"]
        ]

        let summary = try await aiService.makeChatRequest(
            provider: provider,
            model: model,
            systemMessage: summaryPrompt,
            messages: summaryMessages
        )

        // Delete old messages, remove existing summaries
        let toDelete = split.toCompact + messages.filter { $0.isSummary }
        for msg in toDelete {
            modelContext.delete(msg)
        }

        // Insert summary message
        let summaryMessage = ChatMessage(
            role: "summary",
            content: summary,
            aiProviderName: provider.rawValue,
            aiModelName: model,
            isSummary: true,
            estimatedTokenCount: ChatContextManager.estimateTokens(summary)
        )
        summaryMessage.transcription = transcription
        modelContext.insert(summaryMessage)

        trySave()
        loadMessages()
    }

    private func savePartialResponse(provider: AIProvider, model: String) {
        let partial = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !partial.isEmpty else { return }

        let msg = ChatMessage(
            role: "assistant",
            content: partial,
            aiProviderName: provider.rawValue,
            aiModelName: model,
            estimatedTokenCount: ChatContextManager.estimateTokens(partial)
        )
        msg.transcription = transcription
        modelContext.insert(msg)
        messages.append(msg)
        trySave()
    }

    private func persistProviderSelection() {
        transcription.chatAIProviderName = selectedProvider?.rawValue
        transcription.chatAIModelName = selectedModel
        trySave()
    }

    private func trySave() {
        do {
            try modelContext.save()
        } catch {
            logger.logError("Chat - Failed to save context: \(error.localizedDescription)")
        }
    }
}
