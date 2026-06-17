//
//  AIChatService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import AICore

/// Narrow chat-request surface of ``AIService`` consumed by chat view models.
///
/// Carved out so chat view models can be unit-tested against a hand-rolled
/// mock without spinning up a real ``AIService``. The protocol intentionally
/// mirrors only the members the chat view models actually touch.
@MainActor
protocol AIChatService: AnyObject {
    var selectedMode: VivaMode { get }

    func isChatProviderReady(_ provider: AIProvider) -> Bool

    func makeChatStreamingRequest(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String

    func makeChatRequest(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String

    /// Lets the model decide whether to invoke a cross-note search tool.
    /// Returns the focused search query, or `nil` if the model decides not
    /// to search this turn.
    func makeCrossNoteSearchToolDecision(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String?

    /// Lets the model decide whether to invoke the web search tool.
    /// Returns the focused search query, or `nil` if the model decides not
    /// to search this turn.
    func makeWebSearchToolDecision(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String?
}

extension AIService: AIChatService {}
