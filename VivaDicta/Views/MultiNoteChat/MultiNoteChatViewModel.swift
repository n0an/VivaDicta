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
    private let reviewReplyThreshold = 2

    private struct CrossNoteSearchTurnContext {
        let augmentedPrompt: String
        let sourceIDs: [UUID]
        let sourceCitations: [SmartSearchSourceCitation]
        let didActuallySearch: Bool
    }

    private struct WebSearchTurnContext {
        let augmentedPrompt: String
        let didActuallySearch: Bool
    }

    private struct CloudSendResult {
        let text: String
        let implicitToolCitations: [SmartSearchSourceCitation]
        let implicitNoteToolUsed: Bool
        let implicitWebToolUsed: Bool
    }

    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingText: String = ""
    var errorMessage: String?
    var isCompacting: Bool = false
    var isCrossNoteSearchArmed: Bool = false
    var isWebSearchArmed: Bool = false

    var canSearchOtherNotes: Bool {
        SmartSearchFeature.isEnabled
    }

    var canSearchWeb: Bool {
        WebSearchToolFeature.isEnabled && ExaAPIKeyManager.isConfigured
    }

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

    var contextFillRatio: Double = 0

    func updateContextFillRatio() {
        guard let provider = selectedProvider, selectedModel != nil else {
            contextFillRatio = 0
            return
        }

        if provider == .apple {
            Task { await updateAppleFMFillRatio() }
        } else {
            contextFillRatio = 0
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
                logger.logWarning("Multi-note chat - Failed to get token count: \(error.localizedDescription)")
            }
        }

        // Fallback to character-based estimation for iOS 26.0-26.3
        guard let model = selectedModel else { return }
        contextFillRatio = MultiNoteContextManager.fillRatio(
            noteText: assembledNoteText,
            messages: messages,
            provider: .apple,
            model: model
        )
    }

    /// Whether the notes are too large for Apple FM context window.
    /// Computed synchronously on init, then refined with real token count on iOS 26.4+.
    var noteExceedsAppleFMContext: Bool = false

    // MARK: - Dependencies

    let conversation: MultiNoteConversation
    private let aiService: AIService
    private let modelContext: ModelContext
    private var streamingTask: Task<Void, Never>?
    private let notesSearchToolCaptureID = UUID()
    private let webSearchToolCaptureID = UUID()
    /// User message not yet persisted to SwiftData. Re-appended after loadMessages() during send flow.
    private var pendingUserMessage: ChatMessage?
    private var successfulReplyCount = 0
    private var hasRequestedReviewForSession = false

    var assembledNoteText: String {
        conversation.noteContext
    }

    // MARK: - Init

    init(conversation: MultiNoteConversation, aiService: AIService, modelContext: ModelContext) {
        self.conversation = conversation
        self.aiService = aiService
        self.modelContext = modelContext

        loadMessages()
        noteExceedsAppleFMContext = Self.estimateNoteExceedsAppleFM(
            noteText: assembledNoteText,
            systemPrompt: MultiNoteContextManager.systemPrompt
        )

        if selectedProvider == .apple {
            if noteExceedsAppleFMContext {
                errorMessage = "These notes are too long for Apple Foundation Models. Select a different mode with a cloud provider."
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
            errorMessage = "These notes are too long for Apple Foundation Models. Try a cloud provider with a larger context window."
            return
        }

        if isAppleFMResponding { return }

        let shouldSearchOtherNotes = isCrossNoteSearchArmed && canSearchOtherNotes
        let shouldSearchWeb = isWebSearchArmed && canSearchWeb
        isCrossNoteSearchArmed = false
        isWebSearchArmed = false
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

        let chatType: AnalyticsEvent.ChatType = conversation.isAllNotes ? .allNotes : .multiNote
        let turnCount = messages.filter { $0.role == "user" }.count
        if turnCount == 1 {
            AnalyticsService.track(.chatConversationStarted(
                chatType: chatType,
                provider: provider.rawValue,
                model: model,
                noteCount: conversation.sourceNoteCount
            ))
        }
        AnalyticsService.track(.chatMessageSent(
            chatType: chatType,
            provider: provider.rawValue,
            model: model,
            turnCount: turnCount
        ))

        isStreaming = true
        streamingText = ""
        HapticManager.prepareStreaming()

        streamingTask = Task {
            do {
                let result: String
                let implicitToolCitations: [SmartSearchSourceCitation]
                let implicitNoteToolUsed: Bool
                let implicitWebToolUsed: Bool
                let crossNoteContext = await makeCrossNoteSearchContext(
                    for: text,
                    enabled: shouldSearchOtherNotes,
                    provider: provider,
                    model: model
                )
                let promptAfterCrossNote = crossNoteContext?.augmentedPrompt ?? text
                let webSearchContext = await makeWebSearchContext(
                    for: text,
                    basePrompt: promptAfterCrossNote,
                    enabled: shouldSearchWeb,
                    provider: provider,
                    model: model
                )
                let promptText = webSearchContext?.augmentedPrompt ?? promptAfterCrossNote
                let allowImplicitTools = !shouldSearchOtherNotes && !shouldSearchWeb

                if provider == .apple {
                    ExaWebSearchToolRuntime.beginCapture(for: webSearchToolCaptureID)
                    result = try await sendAppleFMMessage(
                        promptText,
                        allowImplicitCrossNoteTool: allowImplicitTools,
                        allowImplicitWebTool: allowImplicitTools
                    )
                    implicitToolCitations = NotesSearchToolRuntime.consumeCapturedCitations(
                        for: notesSearchToolCaptureID
                    )
                    implicitNoteToolUsed = NotesSearchToolRuntime.consumeDidInvoke(
                        for: notesSearchToolCaptureID
                    )
                    implicitWebToolUsed = ExaWebSearchToolRuntime.consumeDidInvoke(
                        for: webSearchToolCaptureID
                    )
                    logger.logInfo(
                        "Multi-note chat - Apple turn completed responseChars=\(result.count) implicitCrossNoteToolUsed=\(implicitNoteToolUsed) implicitWebToolUsed=\(implicitWebToolUsed)"
                    )
                } else {
                    let cloudResult = try await sendCloudMessage(
                        originalText: text,
                        promptText: promptText,
                        provider: provider,
                        model: model,
                        allowImplicitCrossNoteTool: allowImplicitTools,
                        allowImplicitWebTool: allowImplicitTools
                    )
                    result = cloudResult.text
                    implicitToolCitations = cloudResult.implicitToolCitations
                    implicitNoteToolUsed = cloudResult.implicitNoteToolUsed
                    implicitWebToolUsed = cloudResult.implicitWebToolUsed
                }

                // Persist user message now that streaming is done
                pendingUserMessage = nil
                userMessage.multiNoteConversation = conversation
                modelContext.insert(userMessage)

                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: result,
                    aiProviderName: provider.rawValue,
                    aiModelName: model,
                    estimatedTokenCount: ChatContextManager.estimateTokens(result)
                )
                assistantMessage.sourceTranscriptionIds = mergedSourceIDs(
                    explicit: crossNoteContext?.sourceIDs ?? [],
                    implicit: implicitToolCitations
                )
                assistantMessage.sourceCitations = mergeSourceCitations(
                    explicit: crossNoteContext?.sourceCitations ?? [],
                    implicit: implicitToolCitations
                )
                assistantMessage.didUseCrossNoteSearchTool =
                    (crossNoteContext?.didActuallySearch ?? false) || implicitNoteToolUsed
                assistantMessage.didUseWebSearchTool =
                    (webSearchContext?.didActuallySearch ?? false) || implicitWebToolUsed
                assistantMessage.multiNoteConversation = conversation
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)

                successfulReplyCount += 1
                requestReviewIfNeededForSession()

                HapticManager.heartbeat()

            } catch is CancellationError {
                pendingUserMessage = nil
                userMessage.multiNoteConversation = conversation
                modelContext.insert(userMessage)
                savePartialResponse(provider: provider, model: model)
            } catch {
                logger.logError("Multi-note chat error: \(error.localizedDescription)")

                pendingUserMessage = nil
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
            updateContextFillRatio()
        }
    }

    // MARK: - Cancel

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
    }

    func toggleCrossNoteSearchArmed() {
        guard canSearchOtherNotes else {
            isCrossNoteSearchArmed = false
            return
        }
        isCrossNoteSearchArmed.toggle()
        if isCrossNoteSearchArmed {
            isWebSearchArmed = false
        }
    }

    func toggleWebSearchArmed() {
        guard canSearchWeb else {
            isWebSearchArmed = false
            return
        }
        isWebSearchArmed.toggle()
        if isWebSearchArmed {
            isCrossNoteSearchArmed = false
        }
    }

    // MARK: - Clear Chat

    func clearChat() {
        cancelStreaming()
        for message in messages {
            modelContext.delete(message)
        }
        messages.removeAll()
        successfulReplyCount = 0
        hasRequestedReviewForSession = false
        isCrossNoteSearchArmed = false
        isWebSearchArmed = false

        conversation.appleFMTranscriptData = nil
        trySave()

        if selectedProvider == .apple {
            initializeAppleFMSession()
        }

        updateContextFillRatio()
    }

    private func requestReviewIfNeededForSession() {
        guard !hasRequestedReviewForSession, successfulReplyCount >= reviewReplyThreshold else { return }
        hasRequestedReviewForSession = true
        RateAppManager.requestReviewIfAppropriate()
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
            logger.logError("Multi-note chat compaction failed: \(error.localizedDescription)")
            errorMessage = "Compaction failed: \(error.localizedDescription)"
        }
        isCompacting = false
    }

    @available(iOS 26, *)
    private func compactAppleFMSessionImpl() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard let session = appleFMSession else { return }

        // Extract and summarize conversation from transcript
        let conversationText = session.transcript.getMessages().map { entry -> String in
            switch entry {
            case .prompt(let p): return "User: \(p.segments.map { "\($0)" }.joined())"
            case .response(let r): return "Assistant: \(r.segments.map { "\($0)" }.joined())"
            default: return ""
            }
        }.joined(separator: "\n\n")

        guard !conversationText.isEmpty else { return }

        let summarySession = LanguageModelSession(
            instructions: ChatContextManager.compactionPrompt
        )
        let summaryResponse = try await summarySession.respond(
            to: "Summarize this conversation:\n\n\(conversationText)",
            options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 100)
        )
        let summary = summaryResponse.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rebuild session with clean transcript
        let transcript = Transcript.buildCompacted(
            instructions: MultiNoteContextManager.systemPrompt,
            notePrompt: appleFMNotePrompt,
            summary: summary
        )
        appleFMSession = LanguageModelSession(model: appleFMModel, tools: appleFMTools(), transcript: transcript)

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

    // MARK: - Note Exceeds Check

    private static func estimateNoteExceedsAppleFM(noteText: String, systemPrompt: String) -> Bool {
        let noteTokens = ChatContextManager.estimateTokens(noteText)
        let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
        let limit = ChatContextManager.contextLimit(for: .apple, model: "foundation-model")
        return (noteTokens + systemTokens) > Int(Double(limit) * 0.80)
    }

    private func refineNoteExceedsCheck() async {
        guard #available(iOS 26.4, *) else { return }

        let entries: [Transcript.Entry] = [
            .instructions(.init(
                segments: [.text(.init(content: MultiNoteContextManager.systemPrompt))],
                toolDefinitions: []
            )),
            .prompt(.init(segments: [.text(.init(content: assembledNoteText))]))
        ]

        do {
            let usedTokens = try await SystemLanguageModel.default.tokenCount(for: entries)
            let contextSize = SystemLanguageModel.default.contextSize
            let exceeds = contextSize > 0 ? Double(usedTokens) / Double(contextSize) > 0.80 : true

            if noteExceedsAppleFMContext && !exceeds {
                logger.logInfo("Multi-note chat - Real token count shows notes fit (\(usedTokens)/\(contextSize)), clearing error")
                noteExceedsAppleFMContext = false
                errorMessage = nil
                initializeAppleFMSession()
                updateContextFillRatio()
            } else if !noteExceedsAppleFMContext && exceeds {
                logger.logInfo("Multi-note chat - Real token count shows notes too large (\(usedTokens)/\(contextSize))")
                noteExceedsAppleFMContext = true
                errorMessage = "These notes are too long for Apple Foundation Models. Select a different mode with a cloud provider."
            }
        } catch {
            logger.logWarning("Multi-note chat - Failed to refine note size check: \(error.localizedDescription)")
        }
    }

    // MARK: - Apple FM Session Management

    @available(iOS 26, *)
    private var appleFMModel: SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    @available(iOS 26, *)
    private func appleFMTools(
        includeImplicitCrossNoteSearch: Bool = false,
        includeImplicitWebSearch: Bool = true
    ) -> [any Tool] {
        var tools: [any Tool] = []
        if includeImplicitWebSearch,
           WebSearchToolFeature.isEnabled,
           let key = ExaAPIKeyManager.apiKey,
           !key.isEmpty {
            tools.append(ExaWebSearchTool(apiKey: key, captureID: webSearchToolCaptureID))
        }
        if includeImplicitCrossNoteSearch,
           CrossNoteSearchToolFeature.isEnabled,
           SmartSearchFeature.isEnabled {
            let excludedIDs = Set((conversation.transcriptions ?? []).map(\.id))
            tools.append(
                NotesSearchTool(
                    excludedTranscriptionIDs: excludedIDs,
                    captureID: notesSearchToolCaptureID
                )
            )
        }
        return tools
    }

    private func initializeAppleFMSession() {
        guard #available(iOS 26, *) else { return }
        guard AppleFoundationModelAvailability.isAvailable else { return }

        if let data = conversation.appleFMTranscriptData,
           let transcript = try? JSONDecoder().decode(Transcript.self, from: data) {
            let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools(), transcript: transcript)
            session.prewarm()
            appleFMSession = session
            logger.logInfo("Multi-note chat - Apple FM session restored and prewarmed")
            return
        }

        let summary = messages.first(where: { $0.isSummary })?.content
        let transcript = Transcript.buildFresh(
            instructions: MultiNoteContextManager.systemPrompt,
            notePrompt: appleFMNotePrompt,
            noteAcknowledgment: "I've read your \(conversation.sourceNoteCount) notes. Ask me anything about them.",
            summary: summary
        )

        let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools(), transcript: transcript)
        session.prewarm()
        appleFMSession = session
        logger.logInfo("Multi-note chat - Apple FM session initialized and prewarmed")
    }

    /// Note context for Apple FM prompt.
    @available(iOS 26, *)
    private var appleFMNotePrompt: String {
        conversation.noteContext
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
    private func sendAppleFMMessageImpl(
        _ text: String,
        allowImplicitCrossNoteTool: Bool,
        allowImplicitWebTool: Bool
    ) async throws -> String {
        guard let currentSession = appleFMSession else {
            throw EnhancementError.notConfigured
        }

        NotesSearchToolRuntime.beginCapture(for: notesSearchToolCaptureID)

        var session = LanguageModelSession(
            model: appleFMModel,
            tools: appleFMTools(
                includeImplicitCrossNoteSearch: allowImplicitCrossNoteTool,
                includeImplicitWebSearch: allowImplicitWebTool
            ),
            transcript: currentSession.transcript
        )
        logger.logInfo(
            "Multi-note chat - Apple turn start promptChars=\(text.count) implicitCrossNoteToolAllowed=\(allowImplicitCrossNoteTool) implicitWebToolAllowed=\(allowImplicitWebTool)"
        )

        // No preemptive compaction for Apple FM - let the runtime decide via
        // exceededContextWindowSize. Our character-based fill estimate is too
        // inaccurate for Apple FM's small 4K context window.

        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.9),
            temperature: 0.7
        )

        do {
            let result = try await streamAppleFMResponse(session: session, text: text, options: options)
            appleFMSession = session
            saveAppleFMTranscript()
            return result
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.logWarning("Multi-note chat - Apple FM context exceeded, summarizing and retrying")

            isCompacting = true
            session = try await summarizeAndRebuildSession(
                session,
                label: "multi-note",
                includeImplicitCrossNoteSearch: allowImplicitCrossNoteTool,
                includeImplicitWebSearch: allowImplicitWebTool
            )
            appleFMSession = session
            compactSwiftDataMessages()
            isCompacting = false

            let result = try await streamAppleFMResponse(session: session, text: text, options: options)
            appleFMSession = session
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
    private func summarizeAndRebuildSession(
        _ session: LanguageModelSession,
        label: String,
        includeImplicitCrossNoteSearch: Bool = false,
        includeImplicitWebSearch: Bool = true
    ) async throws -> LanguageModelSession {
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

        let transcript = Transcript.buildCompacted(
            instructions: MultiNoteContextManager.systemPrompt,
            notePrompt: appleFMNotePrompt,
            summary: summary
        )
        return LanguageModelSession(
            model: appleFMModel,
            tools: appleFMTools(
                includeImplicitCrossNoteSearch: includeImplicitCrossNoteSearch,
                includeImplicitWebSearch: includeImplicitWebSearch
            ),
            transcript: transcript
        )
    }

    @available(iOS 26, *)
    private func streamAppleFMResponse(
        session: LanguageModelSession,
        text: String,
        options: GenerationOptions
    ) async throws -> String {
        let stream = session.streamResponse(to: text, options: options)
        var didLogFirstChunk = false
        for try await partial in stream {
            let content = partial.content
            let previous = streamingText
            if previous.isEmpty, !content.isEmpty {
                HapticManager.streamingStart()
                if !didLogFirstChunk {
                    logger.logInfo("Multi-note chat - Apple first response chunk chars=\(content.count)")
                    didLogFirstChunk = true
                }
            } else if content.count > previous.count {
                HapticManager.streamingPulse()
            }
            streamingText = content
        }
        let response = try await stream.collect()
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = AIEnhancementOutputFilter.filter(result)
        streamingText = filtered
        logger.logInfo("Multi-note chat - Apple stream collected rawChars=\(result.count) filteredChars=\(filtered.count)")
        return filtered
    }

    private func sendAppleFMMessage(
        _ text: String,
        allowImplicitCrossNoteTool: Bool,
        allowImplicitWebTool: Bool
    ) async throws -> String {
        if #available(iOS 26, *) {
            return try await sendAppleFMMessageImpl(
                text,
                allowImplicitCrossNoteTool: allowImplicitCrossNoteTool,
                allowImplicitWebTool: allowImplicitWebTool
            )
        } else {
            throw EnhancementError.notConfigured
        }
    }

    private func sendCloudMessage(
        originalText: String,
        promptText: String,
        provider: AIProvider,
        model: String,
        allowImplicitCrossNoteTool: Bool,
        allowImplicitWebTool: Bool
    ) async throws -> CloudSendResult {
        let baseChatMessages = cloudChatMessages(for: promptText)
        let (baseSystemMessage, baseAPIMessages) = MultiNoteContextManager.assembleMessages(
            noteText: assembledNoteText,
            chatMessages: baseChatMessages,
            provider: provider,
            model: model
        )

        let implicitCrossNoteContext = await makeImplicitCloudCrossNoteSearchContext(
            originalText: originalText,
            allowImplicitCrossNoteTool: allowImplicitCrossNoteTool,
            provider: provider,
            model: model,
            systemMessage: baseSystemMessage,
            apiMessages: baseAPIMessages
        )

        let promptAfterImplicitCrossNote = implicitCrossNoteContext?.augmentedPrompt ?? promptText
        let webDecisionChatMessages = cloudChatMessages(for: promptAfterImplicitCrossNote)
        let (webDecisionSystemMessage, webDecisionAPIMessages) = MultiNoteContextManager.assembleMessages(
            noteText: assembledNoteText,
            chatMessages: webDecisionChatMessages,
            provider: provider,
            model: model
        )
        let implicitWebContext = await makeImplicitCloudWebSearchContext(
            originalText: originalText,
            basePrompt: promptAfterImplicitCrossNote,
            allowImplicitWebTool: allowImplicitWebTool,
            provider: provider,
            model: model,
            systemMessage: webDecisionSystemMessage,
            apiMessages: webDecisionAPIMessages
        )

        let finalPromptText = implicitWebContext?.augmentedPrompt ?? promptAfterImplicitCrossNote
        let finalChatMessages = cloudChatMessages(for: finalPromptText)
        let (systemMessage, apiMessages) = MultiNoteContextManager.assembleMessages(
            noteText: assembledNoteText,
            chatMessages: finalChatMessages,
            provider: provider,
            model: model
        )

        logger.logInfo(
            "Multi-note chat sending prompt originalChars=\(originalText.count) augmentedChars=\(finalPromptText.count)"
        )

        let text = try await aiService.makeChatStreamingRequest(
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

        let implicitToolCitations = implicitCrossNoteContext?.sourceCitations ?? []
        let implicitNoteToolUsed = implicitCrossNoteContext != nil

        return CloudSendResult(
            text: text,
            implicitToolCitations: implicitToolCitations,
            implicitNoteToolUsed: implicitNoteToolUsed,
            implicitWebToolUsed: implicitWebContext != nil
        )
    }

    // MARK: - Private Helpers

    private func cloudChatMessages(for promptText: String) -> [ChatMessage] {
        let outboundUserMessage = ChatMessage(
            role: "user",
            content: promptText,
            estimatedTokenCount: ChatContextManager.estimateTokens(promptText)
        )
        var allChatMessages = Array(messages.dropLast())
        allChatMessages.append(outboundUserMessage)
        return allChatMessages
    }

    private func makeCrossNoteSearchContext(
        for query: String,
        enabled: Bool,
        provider: AIProvider,
        model: String
    ) async -> CrossNoteSearchTurnContext? {
        guard enabled else { return nil }

        guard let plan = await CrossNoteSearchPlanner.makePlan(
            aiService: aiService,
            provider: provider,
            model: model,
            noteText: assembledNoteText,
            recentMessages: plannerMessagesForCrossNoteSearch(),
            latestUserMessage: query
        ) else {
            logger.logWarning("Multi-note chat - Cross-note planner failed for query='\(query)'")
            return CrossNoteSearchTurnContext(
                augmentedPrompt: ChatCrossNoteContextManager.assemblePlannerUnavailablePrompt(
                    query: query,
                    message: "Other-note search was enabled for this turn, but a focused search query could not be prepared."
                ),
                sourceIDs: [],
                sourceCitations: [],
                didActuallySearch: false
            )
        }

        guard plan.shouldSearch, let plannedQuery = plan.searchQuery else {
            logger.logInfo(
                "Multi-note chat - Cross-note planner decided not to search query='\(query)' reason='\(plan.reasoning ?? "")'"
            )
            return CrossNoteSearchTurnContext(
                augmentedPrompt: ChatCrossNoteContextManager.assemblePlannerUnavailablePrompt(
                    query: query,
                    message: "Other-note search was enabled for this turn, but no focused search query could be inferred from the notes already in the chat and recent conversation."
                ),
                sourceIDs: [],
                sourceCitations: [],
                didActuallySearch: false
            )
        }

        let excludedIDs = Set((conversation.transcriptions ?? []).map(\.id))
        let payload = await NotesSearchToolRuntime.searchNotesPayload(
            query: plannedQuery,
            excluding: excludedIDs
        )

        switch payload.status {
        case .success:
            logger.logInfo(
                "Multi-note chat - Cross-note search found \(payload.results.count) note matches for plannedQuery='\(plannedQuery)' originalQuery='\(query)'"
            )
            return CrossNoteSearchTurnContext(
                augmentedPrompt: ChatCrossNoteContextManager.assembleAugmentedPrompt(
                    query: query,
                    plannedQuery: plannedQuery,
                    payload: payload
                ),
                sourceIDs: payload.sourceIDs,
                sourceCitations: payload.sourceCitations,
                didActuallySearch: true
            )
        case .empty:
            logger.logInfo("Multi-note chat - Cross-note search found no matches for plannedQuery='\(plannedQuery)'")
            return CrossNoteSearchTurnContext(
                augmentedPrompt: ChatCrossNoteContextManager.assembleAugmentedPrompt(
                    query: query,
                    plannedQuery: plannedQuery,
                    payload: payload
                ),
                sourceIDs: [],
                sourceCitations: [],
                didActuallySearch: true
            )
        case .error:
            if let message = payload.message {
                errorMessage = message
                logger.logWarning("Multi-note chat - Cross-note search error: \(message)")
            }
            return nil
        }
    }

    private func makeImplicitCloudCrossNoteSearchContext(
        originalText: String,
        allowImplicitCrossNoteTool: Bool,
        provider: AIProvider,
        model: String,
        systemMessage: String,
        apiMessages: [[String: String]]
    ) async -> CrossNoteSearchTurnContext? {
        guard allowImplicitCrossNoteTool,
              CrossNoteSearchToolFeature.isEnabled,
              SmartSearchFeature.isEnabled else {
            return nil
        }

        do {
            guard let plannedQuery = try await aiService.makeCrossNoteSearchToolDecision(
                provider: provider,
                model: model,
                systemMessage: systemMessage,
                messages: apiMessages
            ) else {
                logger.logInfo("Multi-note chat - Cloud implicit cross-note tool not used provider=\(provider.rawValue)")
                return nil
            }

            logger.logInfo(
                "Multi-note chat - Cloud implicit cross-note tool provider=\(provider.rawValue) plannedQuery='\(plannedQuery)'"
            )

            let excludedIDs = Set((conversation.transcriptions ?? []).map(\.id))
            let payload = await NotesSearchToolRuntime.searchNotesPayload(
                query: plannedQuery,
                excluding: excludedIDs
            )

            switch payload.status {
            case .success:
                logger.logInfo(
                    "Multi-note chat - Cloud implicit cross-note search found \(payload.results.count) note matches for plannedQuery='\(plannedQuery)'"
                )
                return CrossNoteSearchTurnContext(
                    augmentedPrompt: ChatCrossNoteContextManager.assembleAugmentedPrompt(
                        query: originalText,
                        plannedQuery: plannedQuery,
                        payload: payload
                    ),
                    sourceIDs: payload.sourceIDs,
                    sourceCitations: payload.sourceCitations,
                    didActuallySearch: true
                )
            case .empty:
                logger.logInfo("Multi-note chat - Cloud implicit cross-note search found no matches for plannedQuery='\(plannedQuery)'")
                return CrossNoteSearchTurnContext(
                    augmentedPrompt: ChatCrossNoteContextManager.assembleAugmentedPrompt(
                        query: originalText,
                        plannedQuery: plannedQuery,
                        payload: payload
                    ),
                    sourceIDs: [],
                    sourceCitations: [],
                    didActuallySearch: true
                )
            case .error:
                if let message = payload.message {
                    logger.logWarning("Multi-note chat - Cloud implicit cross-note search error: \(message)")
                }
                return nil
            }
        } catch {
            logger.logWarning(
                "Multi-note chat - Cloud implicit cross-note tool phase failed provider=\(provider.rawValue): \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func makeWebSearchContext(
        for query: String,
        basePrompt: String,
        enabled: Bool,
        provider: AIProvider,
        model: String
    ) async -> WebSearchTurnContext? {
        guard enabled, canSearchWeb else { return nil }

        guard let plan = await WebSearchPlanner.makePlan(
            aiService: aiService,
            provider: provider,
            model: model,
            noteText: assembledNoteText,
            recentMessages: plannerMessagesForCrossNoteSearch(),
            latestUserMessage: query
        ) else {
            logger.logWarning("Multi-note chat - Web planner failed for query='\(query)'")
            return WebSearchTurnContext(
                augmentedPrompt: ChatWebSearchContextManager.assemblePlannerUnavailablePrompt(
                    basePrompt: basePrompt,
                    message: "Web search was enabled for this turn, but a focused search query could not be prepared."
                ),
                didActuallySearch: false
            )
        }

        guard plan.shouldSearch, let plannedQuery = plan.searchQuery else {
            logger.logInfo(
                "Multi-note chat - Web planner decided not to search query='\(query)' reason='\(plan.reasoning ?? "")'"
            )
            return WebSearchTurnContext(
                augmentedPrompt: ChatWebSearchContextManager.assemblePlannerUnavailablePrompt(
                    basePrompt: basePrompt,
                    message: "Web search was enabled for this turn, but no focused web search query could be inferred from the notes already in the chat and recent conversation."
                ),
                didActuallySearch: false
            )
        }

        logger.logInfo("Multi-note chat - Web search start originalQuery='\(query)' plannedQuery='\(plannedQuery)'")
        let payload = await ExaWebSearchToolRuntime.searchPayload(query: plannedQuery)

        switch payload.status {
        case .success:
            logger.logInfo(
                "Multi-note chat - Web search found \(payload.results.count) results for plannedQuery='\(plannedQuery)' originalQuery='\(query)'"
            )
            return WebSearchTurnContext(
                augmentedPrompt: ChatWebSearchContextManager.assembleAugmentedPrompt(
                    basePrompt: basePrompt,
                    plannedQuery: plannedQuery,
                    payload: payload
                ),
                didActuallySearch: true
            )
        case .empty:
            logger.logInfo("Multi-note chat - Web search found no matches for plannedQuery='\(plannedQuery)'")
            return WebSearchTurnContext(
                augmentedPrompt: ChatWebSearchContextManager.assembleAugmentedPrompt(
                    basePrompt: basePrompt,
                    plannedQuery: plannedQuery,
                    payload: payload
                ),
                didActuallySearch: true
            )
        case .error:
            if let message = payload.message {
                errorMessage = message
                logger.logWarning("Multi-note chat - Web search error: \(message)")
            }
            return nil
        }
    }

    private func makeImplicitCloudWebSearchContext(
        originalText: String,
        basePrompt: String,
        allowImplicitWebTool: Bool,
        provider: AIProvider,
        model: String,
        systemMessage: String,
        apiMessages: [[String: String]]
    ) async -> WebSearchTurnContext? {
        guard allowImplicitWebTool,
              WebSearchToolFeature.isEnabled,
              canSearchWeb else {
            return nil
        }

        do {
            guard let plannedQuery = try await aiService.makeWebSearchToolDecision(
                provider: provider,
                model: model,
                systemMessage: systemMessage,
                messages: apiMessages
            ) else {
                logger.logInfo("Multi-note chat - Cloud implicit web tool not used provider=\(provider.rawValue)")
                return nil
            }

            logger.logInfo(
                "Multi-note chat - Cloud implicit web tool provider=\(provider.rawValue) plannedQuery='\(plannedQuery)'"
            )

            logger.logInfo(
                "Multi-note chat - Cloud implicit web search start provider=\(provider.rawValue) originalQuery='\(originalText)' plannedQuery='\(plannedQuery)'"
            )
            let payload = await ExaWebSearchToolRuntime.searchPayload(query: plannedQuery)

            switch payload.status {
            case .success:
                logger.logInfo(
                    "Multi-note chat - Cloud implicit web search found \(payload.results.count) results for plannedQuery='\(plannedQuery)'"
                )
                return WebSearchTurnContext(
                    augmentedPrompt: ChatWebSearchContextManager.assembleAugmentedPrompt(
                        basePrompt: basePrompt,
                        plannedQuery: plannedQuery,
                        payload: payload
                    ),
                    didActuallySearch: true
                )
            case .empty:
                logger.logInfo("Multi-note chat - Cloud implicit web search found no matches for plannedQuery='\(plannedQuery)'")
                return WebSearchTurnContext(
                    augmentedPrompt: ChatWebSearchContextManager.assembleAugmentedPrompt(
                        basePrompt: basePrompt,
                        plannedQuery: plannedQuery,
                        payload: payload
                    ),
                    didActuallySearch: true
                )
            case .error:
                if let message = payload.message {
                    logger.logWarning("Multi-note chat - Cloud implicit web search error: \(message)")
                }
                return nil
            }
        } catch {
            logger.logWarning(
                "Multi-note chat - Cloud implicit web tool phase failed provider=\(provider.rawValue): \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func plannerMessagesForCrossNoteSearch() -> [CrossNoteSearchPlannerMessage] {
        messages
            .dropLast()
            .filter { !$0.isSummary }
            .suffix(4)
            .map {
                CrossNoteSearchPlannerMessage(
                    role: $0.role,
                    content: $0.content
                )
            }
    }

    private func mergedSourceIDs(
        explicit: [UUID],
        implicit: [SmartSearchSourceCitation]
    ) -> [UUID] {
        Array(Set(explicit + implicit.map(\.transcriptionId))).sorted { $0.uuidString < $1.uuidString }
    }

    private func mergeSourceCitations(
        explicit: [SmartSearchSourceCitation],
        implicit: [SmartSearchSourceCitation]
    ) -> [SmartSearchSourceCitation] {
        var merged: [UUID: SmartSearchSourceCitation] = [:]

        for citation in explicit + implicit {
            if let existing = merged[citation.transcriptionId] {
                if citation.relevanceScore > existing.relevanceScore {
                    merged[citation.transcriptionId] = citation
                }
            } else {
                merged[citation.transcriptionId] = citation
            }
        }

        return merged.values.sorted { lhs, rhs in
            if lhs.relevanceScore != rhs.relevanceScore {
                return lhs.relevanceScore > rhs.relevanceScore
            }
            return lhs.transcriptionId.uuidString < rhs.transcriptionId.uuidString
        }
    }

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
