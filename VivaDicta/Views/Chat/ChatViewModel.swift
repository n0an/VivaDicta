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

    // MARK: - Provider/Model (from current VivaMode)

    var selectedProvider: AIProvider? { aiService.selectedMode.aiProvider }
    var selectedModel: String? { aiService.selectedMode.aiModel.isEmpty ? nil : aiService.selectedMode.aiModel }

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

    var contextFillRatio: Double = 0

    /// Updates the context fill ratio. Uses real token count for Apple FM on iOS 26.4+,
    /// falls back to character-based estimation for cloud providers and older iOS.
    func updateContextFillRatio() {
        guard let provider = selectedProvider, let model = selectedModel else {
            contextFillRatio = 0
            return
        }

        if provider == .apple {
            Task { await updateAppleFMFillRatio() }
        } else {
            contextFillRatio = ChatContextManager.fillRatio(
                noteText: assembledNoteText,
                messages: messages,
                provider: provider,
                model: model
            )
        }
    }

    private func updateAppleFMFillRatio() async {
        if #available(iOS 26.4, *) {
            guard let session = appleFMSession else {
                contextFillRatio = 0
                return
            }
            do {
                let entries = Array(session.transcript)
                let usedTokens = try await SystemLanguageModel.default.tokenCount(for: entries)
                let contextSize = SystemLanguageModel.default.contextSize
                contextFillRatio = contextSize > 0 ? min(Double(usedTokens) / Double(contextSize), 1.0) : 0
                return
            } catch {
                logger.logWarning("Chat - Failed to get token count: \(error.localizedDescription)")
            }
        }

        // Fallback to character-based estimation for iOS 26.0-26.3
        guard let model = selectedModel else { return }
        contextFillRatio = ChatContextManager.fillRatio(
            noteText: assembledNoteText,
            messages: messages,
            provider: .apple,
            model: model
        )
    }

    /// Whether the note text alone would exceed the Apple FM context window,
    /// leaving no room for chat. Computed synchronously on init (character estimate),
    /// then refined with real token count on iOS 26.4+.
    var noteExceedsAppleFMContext: Bool = false

    // MARK: - Dependencies

    let conversation: ChatConversation
    let transcription: Transcription
    private let aiService: AIService
    private let modelContext: ModelContext
    private var streamingTask: Task<Void, Never>?
    private var pendingUserMessage: ChatMessage?

    /// The note text for this conversation.
    var assembledNoteText: String {
        transcription.text
    }

    // MARK: - Init

    init(conversation: ChatConversation, transcription: Transcription, aiService: AIService, modelContext: ModelContext) {
        self.conversation = conversation
        self.transcription = transcription
        self.aiService = aiService
        self.modelContext = modelContext

        loadMessages()
        noteExceedsAppleFMContext = Self.estimateNoteExceedsAppleFM(
            noteText: assembledNoteText,
            systemPrompt: ChatContextManager.chatSystemPrompt
        )

        if selectedProvider == .apple {
            if noteExceedsAppleFMContext {
                errorMessage = "This note is too long for Apple Foundation Models. Select a different mode with a cloud provider."
                Task { await refineNoteExceedsCheck() }
            } else {
                initializeAppleFMSession()
            }
        }

        updateContextFillRatio()
    }

    // MARK: - Message Loading

    func loadMessages() {
        let sorted = (conversation.messages ?? []).sorted { $0.createdAt < $1.createdAt }
        messages = sorted
        if let pending = pendingUserMessage {
            messages.append(pending)
        }
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
        conversation.lastInteractionAt = Date()
        trySave()

        // Create user message for immediate UI display but defer SwiftData
        // insertion to avoid @Model mutation triggering layout disruption.
        let userMessage = ChatMessage(
            role: "user",
            content: text,
            estimatedTokenCount: ChatContextManager.estimateTokens(text)
        )
        pendingUserMessage = userMessage
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

                pendingUserMessage = nil
                userMessage.conversation = conversation
                modelContext.insert(userMessage)

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
                pendingUserMessage = nil
                userMessage.conversation = conversation
                modelContext.insert(userMessage)
                savePartialResponse(provider: provider, model: model)
            } catch {
                logger.logError("Chat error: \(error.localizedDescription)")

                pendingUserMessage = nil
                userMessage.conversation = conversation
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
                errorMsg.conversation = conversation
                modelContext.insert(errorMsg)
                messages.append(errorMsg)

                HapticManager.error()
            }

            isStreaming = false
            streamingText = ""
            trySave()
            updateContextFillRatio()
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

        updateContextFillRatio()
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

            updateContextFillRatio()
            HapticManager.success()
        } catch {
            logger.logError("Chat compaction failed: \(error.localizedDescription)")
            errorMessage = "Compaction failed: \(error.localizedDescription)"
        }
        isCompacting = false
    }

    @available(iOS 26, *)
    private func compactAppleFMSessionImpl() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard let session = appleFMSession else { return }

        // Extract conversation text from transcript for summarization
        let conversationText = session.transcript.getMessages().map { entry -> String in
            switch entry {
            case .prompt(let p): return "User: \(p.segments.map { "\($0)" }.joined())"
            case .response(let r): return "Assistant: \(r.segments.map { "\($0)" }.joined())"
            default: return ""
            }
        }.joined(separator: "\n\n")

        guard !conversationText.isEmpty else { return }

        // Summarize with a separate session
        let summarySession = LanguageModelSession(
            instructions: ChatContextManager.compactionPrompt
        )
        let summaryResponse = try await summarySession.respond(
            to: "Summarize this conversation:\n\n\(conversationText)",
            options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 100)
        )
        let summary = summaryResponse.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rebuild session with clean transcript: instructions + note + summary
        let transcript = Transcript.buildCompacted(
            instructions: ChatContextManager.chatSystemPrompt,
            notePrompt: appleFMNotePrompt,
            summary: summary
        )
        appleFMSession = LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)

        // Update SwiftData messages
        let nonSummaryMessages = messages.filter { !$0.isSummary }
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages, keepCount: 2) else { return }

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
        summaryMessage.conversation = conversation
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

    // MARK: - Note Exceeds Check

    /// Synchronous character-based estimate with 0.80 threshold (used at init before async is available).
    private static func estimateNoteExceedsAppleFM(noteText: String, systemPrompt: String) -> Bool {
        let noteTokens = ChatContextManager.estimateTokens(noteText)
        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
        let limit = ChatContextManager.contextLimit(for: .apple, model: "foundation-model")
        return (noteTokens + systemTokens) > Int(Double(limit) * 0.80)
    }

    /// Refines `noteExceedsAppleFMContext` with real token count on iOS 26.4+.
    /// If the sync estimate was too conservative, clears the error and initializes the session.
    private func refineNoteExceedsCheck() async {
        guard #available(iOS 26.4, *) else { return }

        let entries: [Transcript.Entry] = [
            .instructions(.init(
                segments: [.text(.init(content: ChatContextManager.chatSystemPrompt))],
                toolDefinitions: []
            )),
            .prompt(.init(segments: [.text(.init(content: assembledNoteText))]))
        ]

        do {
            let usedTokens = try await SystemLanguageModel.default.tokenCount(for: entries)
            let contextSize = SystemLanguageModel.default.contextSize
            let exceeds = contextSize > 0 ? Double(usedTokens) / Double(contextSize) > 0.80 : true

            if noteExceedsAppleFMContext && !exceeds {
                logger.logInfo("Chat - Real token count shows note fits (\(usedTokens)/\(contextSize)), clearing error")
                noteExceedsAppleFMContext = false
                errorMessage = nil
                initializeAppleFMSession()
                updateContextFillRatio()
            } else if !noteExceedsAppleFMContext && exceeds {
                logger.logInfo("Chat - Real token count shows note too large (\(usedTokens)/\(contextSize))")
                noteExceedsAppleFMContext = true
                errorMessage = "This note is too long for Apple Foundation Models. Select a different mode with a cloud provider."
            }
        } catch {
            logger.logWarning("Chat - Failed to refine note size check: \(error.localizedDescription)")
        }
    }

    // MARK: - Apple FM Session Management

    @available(iOS 26, *)
    private var appleFMModel: SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    @available(iOS 26, *)
    private var appleFMTools: [any Tool] {
        guard let key = ExaAPIKeyManager.apiKey, !key.isEmpty else { return [] }
        return [ExaWebSearchTool(apiKey: key)]
    }

    private func initializeAppleFMSession() {
        guard #available(iOS 26, *) else { return }
        guard AppleFoundationModelAvailability.isAvailable else { return }

        if let data = conversation.appleFMTranscriptData,
           let transcript = try? JSONDecoder().decode(Transcript.self, from: data) {
            let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)
            session.prewarm()
            appleFMSession = session
            logger.logInfo("Chat - Apple FM session restored and prewarmed")
            return
        }

        let summary = messages.first(where: { $0.isSummary })?.content
        let transcript = Transcript.buildFresh(
            instructions: ChatContextManager.chatSystemPrompt,
            notePrompt: "<NOTE>\n\(assembledNoteText)\n</NOTE>",
            noteAcknowledgment: "I've read your note. Ask me anything about it.",
            summary: summary
        )

        let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)
        session.prewarm()
        appleFMSession = session
        logger.logInfo("Chat - Apple FM session initialized and prewarmed")
    }

    /// Note text wrapped for Apple FM context.
    @available(iOS 26, *)
    private var appleFMNotePrompt: String {
        "<NOTE>\n\(assembledNoteText)\n</NOTE>"
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

        #if DEBUG
        print("DEBUG APPLE FM [single-note] PROMPT: \(text)")
        print("DEBUG APPLE FM [single-note] TRANSCRIPT ENTRIES BEFORE SEND: \(session.transcript.count)")
        #endif

        // No preemptive compaction for Apple FM - let the runtime decide via
        // exceededContextWindowSize. Our character-based fill estimate is too
        // inaccurate for Apple FM's small 4K context window.

        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.9),
            temperature: 0.7
        )

        do {
            let result = try await streamAppleFMResponse(session: session, text: text, options: options)
            saveAppleFMTranscript()
            return result
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.logWarning("Chat - Apple FM context exceeded, summarizing and retrying")

            isCompacting = true
            session = try await summarizeAndRebuildSession(session, label: "single-note")
            appleFMSession = session
            compactSwiftDataMessages()
            isCompacting = false

            let result = try await streamAppleFMResponse(session: session, text: text, options: options)
            saveAppleFMTranscript()
            return result
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation:
                throw EnhancementError.customError("Content was blocked by safety guidelines")
            case .refusal:
                throw EnhancementError.customError("The AI declined to respond to this request. Try rephrasing.")
            default:
                throw EnhancementError.customError(error.localizedDescription)
            }
        }
    }

    /// Extracts conversation from transcript, summarizes it, rebuilds a clean session.
    @available(iOS 26, *)
    private func summarizeAndRebuildSession(_ session: LanguageModelSession, label: String) async throws -> LanguageModelSession {
        let conversationText = session.transcript.getMessages().map { entry -> String in
            switch entry {
            case .prompt(let p): return "User: \(p.segments.map { "\($0)" }.joined())"
            case .response(let r): return "Assistant: \(r.segments.map { "\($0)" }.joined())"
            default: return ""
            }
        }.joined(separator: "\n\n")

        let summary: String
        if conversationText.isEmpty {
            summary = "Previous conversation context was cleared."
        } else {
            let summarySession = LanguageModelSession(
                instructions: ChatContextManager.compactionPrompt
            )
            let response = try await summarySession.respond(
                to: "Summarize this conversation:\n\n\(conversationText)",
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 100)
            )
            summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        #if DEBUG
        print("DEBUG APPLE FM [\(label)] REBUILT SESSION with summary: \(summary.prefix(200))")
        #endif

        let transcript = Transcript.buildCompacted(
            instructions: ChatContextManager.chatSystemPrompt,
            notePrompt: appleFMNotePrompt,
            summary: summary
        )
        return LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)
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
        print("DEBUG APPLE FM [single-note] RESPONSE (\(filtered.count) chars): \(filtered.prefix(500))")
        session.logTranscript(label: "single-note chat")
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

    /// Compacts SwiftData messages to match the Apple FM session state after compaction.
    /// Keeps only the 2 most recent messages for Apple FM's tight context window.
    private func compactSwiftDataMessages() {
        let nonSummaryMessages = messages.filter { !$0.isSummary }
        guard let split = ChatContextManager.messagesToCompact(from: nonSummaryMessages, keepCount: 2) else { return }

        let summaryText = "\(split.toCompact.count) earlier messages compacted into context."
        let toDelete = split.toCompact + messages.filter { $0.isSummary }
        for msg in toDelete {
            modelContext.delete(msg)
        }

        let summaryMessage = ChatMessage(
            role: "summary",
            content: summaryText,
            isSummary: true,
            estimatedTokenCount: ChatContextManager.estimateTokens(summaryText)
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

    private func trySave() {
        do {
            try modelContext.save()
        } catch {
            logger.logError("Chat - Failed to save context: \(error.localizedDescription)")
        }
    }

}
