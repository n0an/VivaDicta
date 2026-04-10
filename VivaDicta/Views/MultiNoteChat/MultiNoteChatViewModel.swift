//
//  MultiNoteChatViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import FoundationModels
import SwiftData
import os

/// View model for multi-note chat conversations.
///
/// Structurally parallel to ``ChatViewModel`` but works with
/// ``MultiNoteConversation`` and multiple source transcriptions.
/// Uses ``MultiNoteContextManager`` for context assembly.
@Observable
@MainActor
final class MultiNoteChatViewModel {
    private let logger = Logger(category: .multiNoteChat)

    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingText: String = ""
    var errorMessage: String?
    var isCompacting: Bool = false

    // MARK: - Provider/Model (from current VivaMode)

    var selectedProvider: AIProvider? { aiService.selectedMode.aiProvider }
    var selectedModel: String? { aiService.selectedMode.aiModel.isEmpty ? nil : aiService.selectedMode.aiModel }

    // MARK: - Apple FM Session (type-erased)

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
        return MultiNoteContextManager.fillRatio(
            noteText: assembledNoteText,
            messages: messages,
            provider: provider,
            model: model
        )
    }

    var noteExceedsAppleFMContext: Bool {
        let sources = conversation.sources ?? []
        let noteTokens = MultiNoteContextManager.noteTokenCount(from: sources)
        let systemTokens = ChatContextManager.estimateTokens(MultiNoteContextManager.systemPrompt)
        let limit = ChatContextManager.contextLimit(for: .apple, model: "foundation-model")
        return (noteTokens + systemTokens) > Int(Double(limit) * 0.6)
    }

    // MARK: - Note Info

    var noteCount: Int {
        (conversation.sources ?? []).filter { $0.transcription != nil }.count
    }

    var deletedNoteCount: Int {
        (conversation.sources ?? []).filter { $0.transcription == nil }.count
    }

    // MARK: - Dependencies

    let conversation: MultiNoteConversation
    private let aiService: AIService
    private let modelContext: ModelContext
    private var streamingTask: Task<Void, Never>?

    var assembledNoteText: String {
        guard let provider = selectedProvider, let model = selectedModel else {
            return MultiNoteContextManager.assembleNoteText(from: conversation.sources ?? [])
        }
        return MultiNoteContextManager.truncateNotesIfNeeded(
            sources: conversation.sources ?? [],
            provider: provider,
            model: model
        )
    }

    // MARK: - Init

    init(conversation: MultiNoteConversation, aiService: AIService, modelContext: ModelContext) {
        self.conversation = conversation
        self.aiService = aiService
        self.modelContext = modelContext

        loadMessages()

        if selectedProvider == .apple {
            if noteExceedsAppleFMContext {
                errorMessage = "These notes are too long for Apple Foundation Models. Select a different mode with a cloud provider."
            } else {
                initializeAppleFMSession()
            }
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
            errorMessage = "These notes are too long for Apple Foundation Models. Try a cloud provider with a larger context window."
            return
        }

        if isAppleFMResponding { return }

        inputText = ""
        errorMessage = nil

        // Create user message for immediate UI display but defer SwiftData
        // insertion to avoid @Model mutation triggering layout disruption.
        let userMessage = ChatMessage(
            role: "user",
            content: text,
            estimatedTokenCount: ChatContextManager.estimateTokens(text)
        )
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

                // Persist user message now that streaming is done
                userMessage.multiNoteConversation = conversation
                modelContext.insert(userMessage)

                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: result,
                    aiProviderName: provider.rawValue,
                    aiModelName: model,
                    estimatedTokenCount: ChatContextManager.estimateTokens(result)
                )
                assistantMessage.multiNoteConversation = conversation
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)

                HapticManager.heartbeat()

            } catch is CancellationError {
                // Persist the user message even on cancel
                userMessage.multiNoteConversation = conversation
                modelContext.insert(userMessage)
                savePartialResponse(provider: provider, model: model)
            } catch {
                logger.logError("Multi-note chat error: \(error.localizedDescription)")

                // Persist the user message even on error
                userMessage.multiNoteConversation = conversation
                modelContext.insert(userMessage)

                let errorContent = error.localizedDescription
                let errorMsg = ChatMessage(
                    role: "assistant",
                    content: errorContent,
                    aiProviderName: provider.rawValue,
                    aiModelName: model,
                    isError: true,
                    estimatedTokenCount: ChatContextManager.estimateTokens(errorContent)
                )
                errorMsg.multiNoteConversation = conversation
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

        isCompacting = true
        do {
            if provider == .apple {
                try await compactAppleFMSession()
            } else {
                try await performCompaction()
            }
            HapticManager.success()
        } catch {
            logger.logError("Multi-note chat compaction failed: \(error.localizedDescription)")
            errorMessage = "Compaction failed: \(error.localizedDescription)"
        }
        isCompacting = false
    }

    @available(iOS 26, *)
    private func compactAppleFMSessionImpl() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard let session = appleFMSession else { return }

        let instructionsTokens = ChatContextManager.estimateTokens(buildAppleFMInstructions())
        let contextBudget = instructionsTokens + 300
        let compacted = try await session.preemptivelySummarizedIfNeeded(over: 0.0, targetContextTokens: contextBudget)
        if compacted !== session {
            appleFMSession = compacted
        } else {
            appleFMSession = session.compacted()
        }

        let nonSummaryMessages = messages.filter { !$0.isSummary }
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages) else { return }

        let summaryText = "\(split.toCompact.count) earlier messages compacted into context."

        let toDelete = split.toCompact + messages.filter { $0.isSummary }
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
        summaryMessage.multiNoteConversation = conversation
        modelContext.insert(summaryMessage)

        saveAppleFMTranscript()
        trySave()
        loadMessages()
    }

    private func compactAppleFMSession() async throws {
        if #available(iOS 26, *) {
            try await compactAppleFMSessionImpl()
        }
    }

    // MARK: - Apple FM Session Management

    private func initializeAppleFMSession() {
        guard #available(iOS 26, *) else { return }
        guard AppleFoundationModelAvailability.isAvailable else { return }

        if let data = conversation.appleFMTranscriptData,
           let transcript = try? JSONDecoder().decode(Transcript.self, from: data) {
            appleFMSession = LanguageModelSession(transcript: transcript)
            logger.logInfo("Multi-note chat - Apple FM session restored from saved transcript")
            return
        }

        let instructions = buildAppleFMInstructions()
        #if DEBUG
        print("DEBUG APPLE FM [multi-note] INSTRUCTIONS (\(instructions.count) chars):\n\(instructions)")
        #endif
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        appleFMSession = LanguageModelSession(model: model, instructions: instructions)
        logger.logInfo("Multi-note chat - Apple FM session initialized fresh")
    }

    @available(iOS 26, *)
    private func buildAppleFMInstructions() -> String {
        var instructions = MultiNoteContextManager.systemPrompt
        let noteText = MultiNoteContextManager.assembleNoteText(from: conversation.sources ?? [])
        instructions += "\n\n\(noteText)"

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
            logger.logWarning("Multi-note chat - Failed to save Apple FM transcript: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Helpers

    @available(iOS 26, *)
    private func sendAppleFMMessageImpl(_ text: String) async throws -> String {
        guard var session = appleFMSession else {
            throw EnhancementError.notConfigured
        }

        #if DEBUG
        print("DEBUG APPLE FM [multi-note] PROMPT: \(text)")
        print("DEBUG APPLE FM [multi-note] TRANSCRIPT ENTRIES BEFORE SEND: \(session.transcript.count)")
        #endif

        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.9),
            temperature: 0.7
        )

        do {
            let instructionsTokens = ChatContextManager.estimateTokens(buildAppleFMInstructions())
            let contextBudget = instructionsTokens + 300
            let compactedSession = try await session.preemptivelySummarizedIfNeeded(targetContextTokens: contextBudget)
            if compactedSession !== session {
                logger.logInfo("Multi-note chat - Apple FM preemptive summarization triggered")
                session = compactedSession
                appleFMSession = session
            }
        } catch {
            logger.logWarning("Multi-note chat - Preemptive summarization failed: \(error.localizedDescription)")
        }

        do {
            let result = try await streamAppleFMResponse(session: session, text: text, options: options)
            saveAppleFMTranscript()
            return result
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.logWarning("Multi-note chat - Apple FM context exceeded, reactive compaction")
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
        #if DEBUG
        print("DEBUG APPLE FM [multi-note] RESPONSE (\(filtered.count) chars): \(filtered.prefix(500))")
        session.logTranscript(label: "multi-note chat")
        #endif
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
        if MultiNoteContextManager.shouldAutoCompact(
            noteText: assembledNoteText,
            messages: messages,
            provider: provider,
            model: model
        ) {
            logger.logInfo("Multi-note chat - Auto-compacting context")
            try await performCompaction()
        }

        let (systemMessage, apiMessages) = MultiNoteContextManager.assembleMessages(
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
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages) else { return }

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
        summaryMessage.multiNoteConversation = conversation
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
        msg.multiNoteConversation = conversation
        modelContext.insert(msg)
        messages.append(msg)
        trySave()
    }

    private func trySave() {
        do {
            try modelContext.save()
        } catch {
            logger.logError("Multi-note chat - Failed to save context: \(error.localizedDescription)")
        }
    }
}
