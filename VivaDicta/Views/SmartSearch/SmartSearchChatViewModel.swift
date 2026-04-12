//
//  SmartSearchChatViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import Foundation
import FoundationModels
import SwiftData
import os

/// View model for RAG-powered Smart Search conversations.
///
/// Structurally parallel to ``MultiNoteChatViewModel`` but retrieves
/// relevant note context dynamically per message via ``RAGIndexingService``.
@Observable
@MainActor
final class SmartSearchChatViewModel {
    private static let previewCharacterLimit = 220
    private let logger = Logger(category: .smartSearchChat)

    private struct DeterministicSmartSearchResponse {
        let content: String
        let sourceIds: [UUID]
        let sourceCitations: [SmartSearchSourceCitation]
    }

    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingText: String = ""
    var errorMessage: String?
    var isCompacting: Bool = false
    var isSearching: Bool = false

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
        guard let provider = selectedProvider, let model = selectedModel else {
            contextFillRatio = 0
            return
        }

        if provider == .apple {
            Task { await updateAppleFMFillRatio() }
        } else {
            contextFillRatio = SmartSearchContextManager.fillRatio(
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
                logger.logWarning("Smart Search - Failed to get token count: \(error.localizedDescription)")
            }
        }

        guard let model = selectedModel else { return }
        contextFillRatio = SmartSearchContextManager.fillRatio(
            messages: messages,
            provider: .apple,
            model: model
        )
    }

    // MARK: - Dependencies

    let conversation: SmartSearchConversation
    private let aiService: AIService
    private let modelContext: ModelContext
    private var streamingTask: Task<Void, Never>?
    private var pendingUserMessage: ChatMessage?

    // MARK: - Init

    init(conversation: SmartSearchConversation, aiService: AIService, modelContext: ModelContext) {
        self.conversation = conversation
        self.aiService = aiService
        self.modelContext = modelContext

        loadMessages()

        if selectedProvider == .apple {
            initializeAppleFMSession()
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

        if isAppleFMResponding { return }

        inputText = ""
        errorMessage = nil

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
            defer {
                isSearching = false
                isStreaming = false
                streamingText = ""
                trySave()
                updateContextFillRatio()
            }

            do {
                logger.logInfo(
                    "Smart Search send started query='\(Self.preview(text, limit: 80))' provider=\(provider.rawValue) model=\(model)"
                )

                let requestedTopK = provider == .apple ? 3 : 5
                isSearching = true
                let searchResults = try await RAGIndexingService.shared.search(query: text, topK: requestedTopK)
                let transcriptions = resolveTranscriptions(for: searchResults)
                isSearching = false

                if searchResults.isEmpty {
                    logger.logInfo("Smart Search retrieval returned no note context for query='\(Self.preview(text, limit: 80))'")
                } else {
                    logSearchResults(searchResults, transcriptions: transcriptions)
                }

                let substantiveQueryTerms = groundedQueryTerms(from: text)
                if searchResults.isEmpty, !substantiveQueryTerms.isEmpty {
                    let deterministicResponse = noEvidenceResponse(for: text)
                    logger.logInfo(
                        "Smart Search returned deterministic no-evidence response queryTerms=\(substantiveQueryTerms.sorted().joined(separator: ", "))"
                    )
                    persistSuccessfulTurn(
                        userMessage: userMessage,
                        provider: provider,
                        model: model,
                        responseText: deterministicResponse.content,
                        sourceIds: deterministicResponse.sourceIds,
                        sourceCitations: deterministicResponse.sourceCitations
                    )
                    HapticManager.heartbeat()
                    return
                }

                let augmentedPrompt = SmartSearchContextManager.assembleAugmentedPrompt(
                    query: text,
                    searchResults: searchResults,
                    transcriptions: transcriptions
                )
                logger.logInfo(
                    "Smart Search augmented prompt chars=\(augmentedPrompt.count) preview='\(Self.preview(augmentedPrompt))'"
                )

                let sourceIds = uniqueSourceIDs(from: searchResults)
                let sourceCitations = buildSourceCitations(from: searchResults)
                logger.logInfo("Smart Search assigned source IDs: \(describeSourceIDs(sourceIds, transcriptions: transcriptions))")

                let result: String
                if provider == .apple {
                    result = try await sendAppleFMMessage(augmentedPrompt)
                } else {
                    result = try await sendCloudMessage(augmentedPrompt, provider: provider, model: model)
                }

                logger.logInfo(
                    "Smart Search response chars=\(result.count) preview='\(Self.preview(result))'"
                )

                persistSuccessfulTurn(
                    userMessage: userMessage,
                    provider: provider,
                    model: model,
                    responseText: result,
                    sourceIds: sourceIds,
                    sourceCitations: sourceCitations
                )

                HapticManager.heartbeat()

            } catch is CancellationError {
                isSearching = false
                pendingUserMessage = nil
                userMessage.smartSearchConversation = conversation
                modelContext.insert(userMessage)
                savePartialResponse(provider: provider, model: model)
            } catch {
                isSearching = false
                logger.logError("Smart Search error: \(error.localizedDescription)")

                pendingUserMessage = nil
                userMessage.smartSearchConversation = conversation
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
                errorMsg.smartSearchConversation = conversation
                modelContext.insert(errorMsg)
                messages.append(errorMsg)

                HapticManager.error()
            }
        }
    }

    private func uniqueSourceIDs(from searchResults: [RAGSearchResult]) -> [UUID] {
        var seen: Set<UUID> = []
        var ids: [UUID] = []
        ids.reserveCapacity(searchResults.count)

        for result in searchResults {
            if seen.insert(result.transcriptionId).inserted {
                ids.append(result.transcriptionId)
            }
        }

        return ids
    }

    private func buildSourceCitations(from searchResults: [RAGSearchResult]) -> [SmartSearchSourceCitation] {
        searchResults.map { result in
            SmartSearchSourceCitation(
                transcriptionId: result.transcriptionId,
                excerpt: result.chunkText,
                relevanceScore: result.relevanceScore
            )
        }
    }

    private func persistSuccessfulTurn(
        userMessage: ChatMessage,
        provider: AIProvider,
        model: String,
        responseText: String,
        sourceIds: [UUID],
        sourceCitations: [SmartSearchSourceCitation]
    ) {
        pendingUserMessage = nil
        userMessage.smartSearchConversation = conversation
        modelContext.insert(userMessage)

        let assistantMessage = ChatMessage(
            role: "assistant",
            content: responseText,
            aiProviderName: provider.rawValue,
            aiModelName: model,
            estimatedTokenCount: ChatContextManager.estimateTokens(responseText)
        )
        assistantMessage.sourceTranscriptionIds = sourceIds
        assistantMessage.sourceCitations = sourceCitations
        assistantMessage.smartSearchConversation = conversation
        modelContext.insert(assistantMessage)
        messages.append(assistantMessage)
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
            logger.logError("Smart Search compaction failed: \(error.localizedDescription)")
            errorMessage = "Compaction failed: \(error.localizedDescription)"
        }
        isCompacting = false
    }

    @available(iOS 26, *)
    private func compactAppleFMSessionImpl() async throws {
        guard let provider = selectedProvider, let model = selectedModel else { return }
        guard let session = appleFMSession else { return }

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

        // Rebuild session with just instructions + summary (no fixed note context)
        let segment = Transcript.Segment.text(Transcript.TextSegment(content: SmartSearchContextManager.systemPrompt))
        let summarySegment = Transcript.Segment.text(Transcript.TextSegment(content: "Summary of our earlier conversation: \(summary)"))
        let transcript = Transcript(entries: [
            .instructions(.init(segments: [segment], toolDefinitions: [])),
            .response(.init(assetIDs: [], segments: [summarySegment]))
        ])
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
        summaryMessage.smartSearchConversation = conversation
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
            logger.logInfo("Smart Search - Apple FM session restored and prewarmed")
            return
        }

        // Smart Search has no fixed note context - just instructions
        let session = LanguageModelSession(
            model: appleFMModel,
            tools: appleFMTools,
            instructions: SmartSearchContextManager.systemPrompt
        )
        session.prewarm()
        appleFMSession = session
        logger.logInfo("Smart Search - Apple FM session initialized and prewarmed")
    }

    @available(iOS 26, *)
    private func saveAppleFMTranscript() {
        guard let session = appleFMSession else { return }
        do {
            let data = try JSONEncoder().encode(session.transcript)
            conversation.appleFMTranscriptData = data
        } catch {
            logger.logWarning("Smart Search - Failed to save Apple FM transcript: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Helpers

    @available(iOS 26, *)
    private func sendAppleFMMessageImpl(_ augmentedPrompt: String) async throws -> String {
        guard var session = appleFMSession else {
            throw EnhancementError.notConfigured
        }

        logger.logInfo(
            "Smart Search Apple FM request chars=\(augmentedPrompt.count) preview='\(Self.preview(augmentedPrompt))'"
        )

        #if DEBUG
        print("DEBUG APPLE FM [smart-search] PROMPT: \(augmentedPrompt.prefix(500))")
        print("DEBUG APPLE FM [smart-search] TRANSCRIPT ENTRIES BEFORE SEND: \(session.transcript.count)")
        #endif

        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.9),
            temperature: 0.7
        )

        do {
            let result = try await streamAppleFMResponse(session: session, text: augmentedPrompt, options: options)
            saveAppleFMTranscript()
            return result
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.logWarning("Smart Search - Apple FM context exceeded, summarizing and retrying")

            isCompacting = true
            session = try await summarizeAndRebuildSession(session)
            appleFMSession = session
            compactSwiftDataMessages()
            isCompacting = false

            let result = try await streamAppleFMResponse(session: session, text: augmentedPrompt, options: options)
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

    @available(iOS 26, *)
    private func summarizeAndRebuildSession(_ session: LanguageModelSession) async throws -> LanguageModelSession {
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
        print("DEBUG APPLE FM [smart-search] REBUILT SESSION with summary: \(summary.prefix(200))")
        #endif

        let segment = Transcript.Segment.text(Transcript.TextSegment(content: SmartSearchContextManager.systemPrompt))
        let summarySegment = Transcript.Segment.text(Transcript.TextSegment(content: "Summary of our earlier conversation: \(summary)"))
        let transcript = Transcript(entries: [
            .instructions(.init(segments: [segment], toolDefinitions: [])),
            .response(.init(assetIDs: [], segments: [summarySegment]))
        ])
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
        print("DEBUG APPLE FM [smart-search] RESPONSE (\(filtered.count) chars): \(filtered.prefix(500))")
        session.logTranscript(label: "smart-search")
        #endif
        streamingText = filtered
        return filtered
    }

    private func sendAppleFMMessage(_ augmentedPrompt: String) async throws -> String {
        if #available(iOS 26, *) {
            return try await sendAppleFMMessageImpl(augmentedPrompt)
        } else {
            throw EnhancementError.notConfigured
        }
    }

    private func sendCloudMessage(_ augmentedPrompt: String, provider: AIProvider, model: String) async throws -> String {
        if SmartSearchContextManager.shouldAutoCompact(
            messages: messages,
            provider: provider,
            model: model
        ) {
            logger.logInfo("Smart Search - Auto-compacting context")
            try await performCompaction()
        }

        // Build messages with augmented prompt as the latest user message
        var chatMessages = messages.dropLast() // Exclude the pending user message
        let augmentedUserMessage = ChatMessage(
            role: "user",
            content: augmentedPrompt,
            estimatedTokenCount: ChatContextManager.estimateTokens(augmentedPrompt)
        )
        var allChatMessages = Array(chatMessages)
        allChatMessages.append(augmentedUserMessage)

        let (systemMessage, apiMessages) = SmartSearchContextManager.assembleMessages(
            chatMessages: allChatMessages,
            provider: provider,
            model: model
        )

        logger.logInfo(
            "Smart Search cloud request provider=\(provider.rawValue) model=\(model) messages=\(apiMessages.count) systemChars=\(systemMessage.count) promptChars=\(augmentedPrompt.count)"
        )
        logger.logDebug("Smart Search cloud prompt preview='\(Self.preview(augmentedPrompt))'")

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

    // MARK: - RAG Helpers

    /// Resolves Transcription objects from RAG search results via the model context.
    private func resolveTranscriptions(for results: [RAGSearchResult]) -> [Transcription] {
        let ids = results.map(\.transcriptionId)
        return resolveTranscriptions(ids: ids)
    }

    private func resolveTranscriptions(ids: [UUID]) -> [Transcription] {
        guard !ids.isEmpty else { return [] }

        var transcriptions: [Transcription] = []
        for id in ids {
            let descriptor = FetchDescriptor<Transcription>(
                predicate: #Predicate { $0.id == id }
            )
            if let transcription = try? modelContext.fetch(descriptor).first {
                transcriptions.append(transcription)
            } else {
                logger.logWarning("Smart Search could not resolve transcription id=\(id.uuidString)")
            }
        }
        logger.logInfo("Smart Search resolved \(transcriptions.count)/\(ids.count) transcriptions for current retrieval")
        return transcriptions
    }

    private func noEvidenceResponse(for query: String) -> DeterministicSmartSearchResponse {
        let response: String
        if isLikelyRussian(query) {
            response = "Я не нашел надежного упоминания этого в ваших заметках."
        } else {
            response = "I could not find a reliable mention of that in your notes."
        }

        return DeterministicSmartSearchResponse(
            content: response,
            sourceIds: [],
            sourceCitations: []
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
        summaryMessage.smartSearchConversation = conversation
        modelContext.insert(summaryMessage)

        trySave()
        loadMessages()
    }

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
        summaryMessage.smartSearchConversation = conversation
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
        msg.smartSearchConversation = conversation
        modelContext.insert(msg)
        messages.append(msg)
        trySave()
    }

    private func trySave() {
        do {
            try modelContext.save()
        } catch {
            logger.logError("Smart Search - Failed to save context: \(error.localizedDescription)")
        }
    }

    private func logSearchResults(_ searchResults: [RAGSearchResult], transcriptions: [Transcription]) {
        let transcriptionMap = Dictionary(uniqueKeysWithValues: transcriptions.map { ($0.id, $0) })

        logger.logInfo(
            "Smart Search retrieval yielded \(searchResults.count) deduped hits across \(transcriptions.count) resolved notes"
        )

        for (index, result) in searchResults.enumerated() {
            let title = transcriptionMap[result.transcriptionId]
                .map { noteTitle(for: $0) } ?? "Missing note"
            logger.logInfo(
                "Smart Search hit[\(index + 1)] noteId=\(result.transcriptionId.uuidString) title='\(title)' score=\(Double(result.relevanceScore).formatted(.number.precision(.fractionLength(3)))) excerpt='\(Self.preview(result.chunkText))'"
            )
        }
    }

    private func describeSourceIDs(_ sourceIds: [UUID], transcriptions: [Transcription]) -> String {
        let transcriptionMap = Dictionary(uniqueKeysWithValues: transcriptions.map { ($0.id, $0) })
        let summaries = sourceIds.map { id in
            let title = transcriptionMap[id].map { noteTitle(for: $0) } ?? "Missing note"
            return "\(id.uuidString):\(title)"
        }
        return summaries.isEmpty ? "none" : summaries.joined(separator: " | ")
    }

    private func noteTitle(for transcription: Transcription) -> String {
        let firstLine = transcription.text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = firstLine.map { String($0.prefix(60)) } ?? "Untitled"
        return title.isEmpty ? "Untitled" : title
    }

    private func groundedQueryTerms(from query: String) -> Set<String> {
        SmartSearchLexicalSupport.queryTerms(from: query)
    }

    private func isLikelyRussian(_ text: String) -> Bool {
        text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil
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

}
