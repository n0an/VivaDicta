//
//  MockAIChatService.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
@testable import VivaDicta
import AICore

/// Hand-rolled mock for ``AIChatService`` following the Bev pattern:
/// per-method `stub...` for return values, `...CallCount` for invocation
/// counts, and a `last...` capture of the most recent arguments.
@MainActor
final class MockAIChatService: AIChatService {

    // MARK: - selectedMode

    var stubSelectedMode: VivaMode = .defaultMode
    var selectedMode: VivaMode { stubSelectedMode }

    // MARK: - isChatProviderReady

    var stubIsChatProviderReady: Bool = true
    var isChatProviderReadyCallCount = 0
    var lastIsChatProviderReadyProvider: AIProvider?
    func isChatProviderReady(_ provider: AIProvider) -> Bool {
        isChatProviderReadyCallCount += 1
        lastIsChatProviderReadyProvider = provider
        return stubIsChatProviderReady
    }

    // MARK: - Captures (shared shape for both chat request methods)

    struct ChatRequestCapture: Equatable {
        let provider: AIProvider
        let model: String
        let systemMessage: String
        let messages: [[String: String]]
    }

    // MARK: - makeChatRequest

    var stubMakeChatRequestResult: Result<String, Error> = .success("")
    var makeChatRequestCallCount = 0
    var lastMakeChatRequestCapture: ChatRequestCapture?
    func makeChatRequest(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String {
        makeChatRequestCallCount += 1
        lastMakeChatRequestCapture = ChatRequestCapture(
            provider: provider,
            model: model,
            systemMessage: systemMessage,
            messages: messages
        )
        return try stubMakeChatRequestResult.get()
    }

    // MARK: - makeChatStreamingRequest

    var stubMakeChatStreamingRequestResult: Result<String, Error> = .success("")
    var stubMakeChatStreamingRequestPartials: [String] = []
    var makeChatStreamingRequestCallCount = 0
    var lastMakeChatStreamingRequestCapture: ChatRequestCapture?
    func makeChatStreamingRequest(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        makeChatStreamingRequestCallCount += 1
        lastMakeChatStreamingRequestCapture = ChatRequestCapture(
            provider: provider,
            model: model,
            systemMessage: systemMessage,
            messages: messages
        )
        for partial in stubMakeChatStreamingRequestPartials {
            await onPartialResponse(partial)
        }
        return try stubMakeChatStreamingRequestResult.get()
    }

    // MARK: - makeCrossNoteSearchToolDecision

    var stubMakeCrossNoteSearchToolDecisionResult: Result<String?, Error> = .success(nil)
    var makeCrossNoteSearchToolDecisionCallCount = 0
    var lastMakeCrossNoteSearchToolDecisionCapture: ChatRequestCapture?
    func makeCrossNoteSearchToolDecision(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String? {
        makeCrossNoteSearchToolDecisionCallCount += 1
        lastMakeCrossNoteSearchToolDecisionCapture = ChatRequestCapture(
            provider: provider,
            model: model,
            systemMessage: systemMessage,
            messages: messages
        )
        return try stubMakeCrossNoteSearchToolDecisionResult.get()
    }

    // MARK: - makeWebSearchToolDecision

    var stubMakeWebSearchToolDecisionResult: Result<String?, Error> = .success(nil)
    var makeWebSearchToolDecisionCallCount = 0
    var lastMakeWebSearchToolDecisionCapture: ChatRequestCapture?
    func makeWebSearchToolDecision(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String? {
        makeWebSearchToolDecisionCallCount += 1
        lastMakeWebSearchToolDecisionCapture = ChatRequestCapture(
            provider: provider,
            model: model,
            systemMessage: systemMessage,
            messages: messages
        )
        return try stubMakeWebSearchToolDecisionResult.get()
    }
}
