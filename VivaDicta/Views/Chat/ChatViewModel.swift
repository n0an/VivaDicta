//
//  ChatViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation
import FoundationModels
import SwiftData
import os

/// View model for the "Chat with Note" feature.
///
/// Manages message history, AI communication, provider/model selection,
/// and context window compaction. Supports single-note and (future) multi-note
/// conversations via the ``ChatConversation`` model.
///
/// For Apple Foundation Models, maintains a persistent `LanguageModelSession`
/// that accumulates context across turns. For cloud providers, assembles
/// the full message array on each request.
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

    // MARK: - Apple FM Session (type-erased for iOS version compatibility)

    private var _appleFMSession: Any?

    @available(iOS 26, *)
    private var appleFMSession: LanguageModelSession? {
        get { _appleFMSession as? LanguageModelSession }
        set { _appleFMSession = newValue }
    }

    var isAppleFMResponding: Bool {
        guard selectedProvider == .apple else { return false }
        if #available(iOS 26, *) {
            return appleFMSession?.isResponding ?? false
        }
        return false
    }

    // MARK: - Context

    var contextFillRatio: Double {
        guard let provider = selectedProvider, let model = selectedModel else { return 0 }
        return ChatContextManager.fillRatio(
            noteText: assembledNoteText,
            messages: messages,
            provider: provider,
            model: model
        )
    }

    /// Whether the note text alone exceeds Apple FM's context window (leaving no room for chat).
    var noteExceedsAppleFMContext: Bool {
        let noteTokens = ChatContextManager.estimateTokens(assembledNoteText)
        let systemTokens = ChatContextManager.estimateTokens(ChatContextManager.chatSystemPrompt)
        let limit = ChatContextManager.contextLimit(for: .apple, model: "foundation-model")
        // Note + system prompt should leave at least 25% for conversation
        return (noteTokens + systemTokens) > (limit * 3 / 4)
    }

    // MARK: - Dependencies

    let conversation: ChatConversation
    let sourceTranscriptions: [Transcription]
    private let aiService: AIService
    private let modelContext: ModelContext
    private var streamingTask: Task<Void, Never>?

    /// Combined note text from all source transcriptions.
    var assembledNoteText: String {
        sourceTranscriptions.map(\.text).joined(separator: "\n\n---\n\n")
    }

    // MARK: - Init

    init(conversation: ChatConversation, sourceTranscriptions: [Transcription], aiService: AIService, modelContext: ModelContext) {
        self.conversation = conversation
        self.sourceTranscriptions = sourceTranscriptions
        self.aiService = aiService
        self.modelContext = modelContext

        // Restore persisted provider/model or default to current mode
        if let providerName = conversation.aiProviderName,
           let provider = AIProvider(rawValue: providerName) {
            self.selectedProvider = provider
            self.selectedModel = conversation.aiModelName ?? provider.defaultModel
        } else if let modeProvider = aiService.selectedMode.aiProvider {
            self.selectedProvider = modeProvider
            self.selectedModel = aiService.selectedMode.aiModel
        }

        loadMessages()

        if selectedProvider == .apple {
            initializeAppleFMSession()
        }
    }

    // MARK: - Message Loading

    func loadMessages() {
        let sorted = (conversation.messages ?? []).sorted { $0.createdAt < $1.createdAt }
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

        if provider == .apple, noteExceedsAppleFMContext {
            errorMessage = "This note is too long for Apple Foundation Models. Try a cloud provider with a larger context window."
            return
        }

        if isAppleFMResponding {
            return
        }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(
            role: "user",
            content: text,
            estimatedTokenCount: ChatContextManager.estimateTokens(text)
        )
        userMessage.conversation = conversation
        modelContext.insert(userMessage)
        messages.append(userMessage)

        isStreaming = true
        streamingText = ""
        HapticManager.prepareStreaming()

        streamingTask = Task {
            do {
                let result: String

                if provider == .apple {
                    result = try await sendAppleFMMessage(text)
                } else {
                    result = try await sendCloudMessage(text, provider: provider, model: model)
                }

                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: result,
                    aiProviderName: provider.rawValue,
                    aiModelName: model,
                    estimatedTokenCount: ChatContextManager.estimateTokens(result)
                )
                assistantMessage.conversation = conversation
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)

                HapticManager.heartbeat()

            } catch is CancellationError {
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
                errorMsg.conversation = conversation
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

        conversation.appleFMTranscriptData = nil
        trySave()

        if selectedProvider == .apple {
            initializeAppleFMSession()
        }
    }

    // MARK: - Compact Chat

    func compactChat() async {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard aiService.isChatProviderReady(provider) else { return }

        print("DEBUG COMPACT: compactChat() called, provider: \(provider.displayName), fill ratio before: \(contextFillRatio)")

        isCompacting = true
        do {
            if provider == .apple {
                try await compactAppleFMSession()
            } else {
                try await performCompaction()
            }

            print("DEBUG COMPACT: compactChat() succeeded, fill ratio after: \(contextFillRatio)")
            HapticManager.success()
        } catch {
            print("DEBUG COMPACT: compactChat() failed: \(error)")
            logger.logError("Chat compaction failed: \(error.localizedDescription)")
            errorMessage = "Compaction failed: \(error.localizedDescription)"
        }
        isCompacting = false
    }

    @available(iOS 26, *)
    private func compactAppleFMSessionImpl() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard let session = appleFMSession else { return }

        print("DEBUG COMPACT: Starting Apple FM compaction")
        print("DEBUG COMPACT: Session transcript entries: \(session.transcript.count)")
        print("DEBUG COMPACT: SwiftData messages count: \(messages.count)")

        let contextBudget = SystemLanguageModel.default.contextSize / 2
        let compacted = try await session.preemptivelySummarizedIfNeeded(over: 0.0, targetContextTokens: contextBudget)
        if compacted !== session {
            appleFMSession = compacted
            print("DEBUG COMPACT: Session compacted via summarization, new transcript entries: \(compacted.transcript.count)")
        } else {
            let greedy = session.compacted()
            appleFMSession = greedy
            print("DEBUG COMPACT: Session compacted via greedy, new transcript entries: \(greedy.transcript.count)")
        }

        let nonSummaryMessages = messages.filter { !$0.isSummary }
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages) else {
            print("DEBUG COMPACT: Not enough messages to compact (need >4 non-summary)")
            return
        }

        print("DEBUG COMPACT: Compacting \(split.toCompact.count) messages, keeping \(split.toKeep.count)")

        // Log what the internal session summary looks like
        if let compactedSession = appleFMSession {
            let transcriptDescription = String(describing: compactedSession.transcript)
            print("DEBUG COMPACT: Session internal transcript after compaction (full):\n\(transcriptDescription)")
        }

        let summaryText = "\(split.toCompact.count) earlier messages compacted into context."

        let toDelete = split.toCompact + messages.filter { $0.isSummary }
        print("DEBUG COMPACT: Deleting \(toDelete.count) messages from SwiftData")
        for msg in toDelete {
            modelContext.delete(msg)
        }

        let summaryMessage = ChatMessage(
            role: "summary",
            content: summaryText,
            aiProviderName: provider.rawValue,
            aiModelName: model,
            isSummary: true,
            estimatedTokenCount: ChatContextManager.estimateTokens(summaryText)
        )
        summaryMessage.conversation = conversation
        modelContext.insert(summaryMessage)

        saveAppleFMTranscript()
        trySave()
        loadMessages()

        print("DEBUG COMPACT: Done. Messages after: \(messages.count), fill ratio: \(contextFillRatio)")
    }

    private func compactAppleFMSession() async throws {
        if #available(iOS 26, *) {
            try await compactAppleFMSessionImpl()
        }
    }

    // MARK: - Provider/Model Update

    func updateProvider(_ provider: AIProvider) {
        selectedProvider = provider
        selectedModel = provider.defaultModel
        persistProviderSelection()

        if provider == .apple {
            initializeAppleFMSession()
        } else {
            _appleFMSession = nil
        }
    }

    func updateModel(_ model: String) {
        selectedModel = model
        persistProviderSelection()
    }

    // MARK: - Apple FM Session Management

    private func initializeAppleFMSession() {
        guard #available(iOS 26, *) else { return }
        guard AppleFoundationModelAvailability.isAvailable else { return }

        if let data = conversation.appleFMTranscriptData,
           let transcript = try? JSONDecoder().decode(Transcript.self, from: data) {
            appleFMSession = LanguageModelSession(transcript: transcript)
            logger.logInfo("Chat - Apple FM session restored from saved transcript")
            return
        }

        let instructions = buildAppleFMInstructions()
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        appleFMSession = LanguageModelSession(model: model, instructions: instructions)
        logger.logInfo("Chat - Apple FM session initialized fresh")
    }

    @available(iOS 26, *)
    private func buildAppleFMInstructions() -> String {
        var instructions = ChatContextManager.chatSystemPrompt
        instructions += "\n\n<NOTE>\n\(assembledNoteText)\n</NOTE>"

        if let summary = messages.first(where: { $0.isSummary }) {
            instructions += "\n\nPrevious conversation summary:\n\(summary.content)"
        }

        return instructions
    }

    @available(iOS 26, *)
    private func saveAppleFMTranscript() {
        guard let session = appleFMSession else { return }
        do {
            let data = try JSONEncoder().encode(session.transcript)
            conversation.appleFMTranscriptData = data
        } catch {
            logger.logWarning("Chat - Failed to save Apple FM transcript: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Helpers

    @available(iOS 26, *)
    private func sendAppleFMMessageImpl(_ text: String) async throws -> String {
        guard var session = appleFMSession else {
            throw EnhancementError.notConfigured
        }

        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.9),
            temperature: 0.7
        )

        do {
            let contextBudget = SystemLanguageModel.default.contextSize / 2
            let compactedSession = try await session.preemptivelySummarizedIfNeeded(targetContextTokens: contextBudget)
            if compactedSession !== session {
                logger.logInfo("Chat - Apple FM preemptive summarization triggered")
                session = compactedSession
                appleFMSession = session
            }
        } catch {
            logger.logWarning("Chat - Preemptive summarization failed: \(error.localizedDescription)")
        }

        do {
            let result = try await streamAppleFMResponse(session: session, text: text, options: options)
            saveAppleFMTranscript()
            return result
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.logWarning("Chat - Apple FM context exceeded, reactive compaction")
            session = session.compacted()
            appleFMSession = session

            do {
                let result = try await streamAppleFMResponse(session: session, text: text, options: options)
                saveAppleFMTranscript()
                return result
            } catch {
                throw EnhancementError.customError("Failed after compaction: \(error.localizedDescription)")
            }
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation:
                throw EnhancementError.customError("Content was blocked by safety guidelines")
            default:
                throw EnhancementError.customError(error.localizedDescription)
            }
        }
    }

    @available(iOS 26, *)
    private func streamAppleFMResponse(
        session: LanguageModelSession,
        text: String,
        options: GenerationOptions
    ) async throws -> String {
        let stream = session.streamResponse(to: text, options: options)
        for try await partial in stream {
            let content = partial.content
            let previous = streamingText
            if previous.isEmpty, !content.isEmpty {
                HapticManager.streamingStart()
            } else if content.count > previous.count {
                HapticManager.streamingPulse()
            }
            streamingText = content
        }
        let response = try await stream.collect()
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = AIEnhancementOutputFilter.filter(result)
        streamingText = filtered
        return filtered
    }

    private func sendAppleFMMessage(_ text: String) async throws -> String {
        if #available(iOS 26, *) {
            return try await sendAppleFMMessageImpl(text)
        } else {
            throw EnhancementError.notConfigured
        }
    }

    private func sendCloudMessage(_ text: String, provider: AIProvider, model: String) async throws -> String {
        if ChatContextManager.shouldAutoCompact(
            noteText: assembledNoteText,
            messages: messages,
            provider: provider,
            model: model
        ) {
            logger.logInfo("Chat - Auto-compacting context")
            try await performCompaction()
        }

        let (systemMessage, apiMessages) = ChatContextManager.assembleMessages(
            noteText: assembledNoteText,
            chatMessages: messages,
            provider: provider,
            model: model
        )

        return try await aiService.makeChatStreamingRequest(
            provider: provider,
            model: model,
            systemMessage: systemMessage,
            messages: apiMessages,
            onPartialResponse: { [weak self] partial in
                guard let self else { return }
                let previous = self.streamingText
                if previous.isEmpty, !partial.isEmpty {
                    HapticManager.streamingStart()
                } else if partial.count > previous.count {
                    HapticManager.streamingPulse()
                }
                self.streamingText = partial
            }
        )
    }

    // MARK: - Private Helpers

    private func performCompaction() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }

        let nonSummaryMessages = messages.filter { !$0.isSummary }
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages) else {
            return
        }

        let transcript = ChatContextManager.formatForCompaction(split.toCompact)

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

        let toDelete = split.toCompact + messages.filter { $0.isSummary }
        for msg in toDelete {
            modelContext.delete(msg)
        }

        let summaryMessage = ChatMessage(
            role: "summary",
            content: summary,
            aiProviderName: provider.rawValue,
            aiModelName: model,
            isSummary: true,
            estimatedTokenCount: ChatContextManager.estimateTokens(summary)
        )
        summaryMessage.conversation = conversation
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
        msg.conversation = conversation
        modelContext.insert(msg)
        messages.append(msg)
        trySave()
    }

    private func persistProviderSelection() {
        conversation.aiProviderName = selectedProvider?.rawValue
        conversation.aiModelName = selectedModel
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
