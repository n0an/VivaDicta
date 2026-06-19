// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import OAuth
import Testing
@testable import AIProviders
import AICore

/// Tests cover `CopilotAPIClient`'s non-streaming surface: `enhance`
/// (both the Anthropic-routed `claude-` branch and the OpenAI-routed
/// default branch, the request shape, success parsing, and the status
/// handling the client does itself), and `fetchModels` (parsing the
/// `data[].id` list and the fallback behaviour on garbage/failed
/// responses).
///
/// `CopilotAPIClient` is a `public enum` with a `nonisolated(unsafe)
/// static var networkService`, i.e. shared mutable state. The suite is
/// `.serialized` so tests never race on it, and every test sets
/// `CopilotAPIClient.networkService` at the top before exercising.
///
/// The streaming paths (`enhanceStreaming` and helpers) route through
/// `networkService.bytes(for:)`, which `MockNetworkService` cannot stub
/// (`URLSession.AsyncBytes` has no public initializer), so they are not
/// covered here.
@Suite("CopilotAPIClient", .serialized, .tags(.networking))
struct CopilotAPIClientTests {

    private func makeHTTPResponse(_ code: Int) -> HTTPURLResponse {
        let url = URL(string: "\(CopilotAPIClient.baseURL)/chat/completions")!
        return HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - enhance success (OpenAI branch)

    @Test func enhanceReturnsTrimmedContentForOpenAIModel() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"{"choices":[{"message":{"content":"  enhanced output  "}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let result = try await CopilotAPIClient.enhance(
            text: "rewrite this",
            systemPrompt: "you are a helper",
            model: "gpt-4o",
            copilotToken: "copilot-token"
        )

        #expect(result == "enhanced output")
    }

    // MARK: - enhance success (Anthropic branch)

    @Test func enhanceReturnsTrimmedContentForClaudeModel() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        // Copilot returns OpenAI-style choices even for Claude models.
        let body = Data(#"{"choices":[{"message":{"content":"claude reply"}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let result = try await CopilotAPIClient.enhance(
            text: "rewrite this",
            systemPrompt: "you are a helper",
            model: "claude-sonnet-4-5",
            copilotToken: "copilot-token"
        )

        #expect(result == "claude reply")
    }

    // MARK: - enhance request shape

    @Test func enhanceTargetsChatCompletionsEndpointWithAuthAndChatHeaders() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        _ = try await CopilotAPIClient.enhance(
            text: "u",
            systemPrompt: "s",
            model: "gpt-4o",
            copilotToken: "copilot-token"
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.url?.absoluteString == "\(CopilotAPIClient.baseURL)/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer copilot-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        // A representative static chat header is forwarded.
        #expect(request.value(forHTTPHeaderField: "Copilot-Integration-Id") == "vscode-chat")
    }

    @Test func enhanceSendsModelAndMessagesBody() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        _ = try await CopilotAPIClient.enhance(
            text: "rewrite this",
            systemPrompt: "you are helpful",
            model: "gpt-4o",
            copilotToken: "copilot-token"
        )

        let httpBody = try #require(networkService.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(json["model"] as? String == "gpt-4o")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [
            ["role": "system", "content": "you are helpful"],
            ["role": "user", "content": "rewrite this"]
        ])
    }

    // MARK: - enhance status handling

    @Test func enhanceMaps429ToRateLimitCustomError() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(429)))

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await CopilotAPIClient.enhance(
                text: "u",
                systemPrompt: "s",
                model: "gpt-4o",
                copilotToken: "copilot-token"
            )
        }
        guard case let .customError(message) = error else {
            Issue.record("Expected .customError, got \(error)")
            return
        }
        #expect(message.localizedStandardContains("rate limit"))
    }

    @Test func enhanceThrowsCopilotOAuthErrorOnOtherNon2xx() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"{"error":"unauthorized"}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(401)))

        let error = try await #require(throws: CopilotOAuthError.self) {
            _ = try await CopilotAPIClient.enhance(
                text: "u",
                systemPrompt: "s",
                model: "gpt-4o",
                copilotToken: "copilot-token"
            )
        }
        guard case let .tokenExchangeFailed(message) = error else {
            Issue.record("Expected .tokenExchangeFailed, got \(error)")
            return
        }
        #expect(message.hasPrefix("HTTP 401"))
    }

    // MARK: - fetchModels

    @Test func fetchModelsReturnsSortedFilteredIDs() async {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"""
        {"data":[
            {"id":"gpt-4o"},
            {"id":"claude-sonnet-4-5"},
            {"id":"text-embedding-3-small"},
            {"id":"some-inference-model"}
        ]}
        """#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let models = await CopilotAPIClient.fetchModels(copilotToken: "copilot-token")

        // Embedding and inference models are filtered out; the rest are sorted.
        #expect(models == ["claude-sonnet-4-5", "gpt-4o"])
    }

    @Test func fetchModelsTargetsModelsEndpointWithAuth() async throws {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"{"data":[{"id":"gpt-4o"}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        _ = await CopilotAPIClient.fetchModels(copilotToken: "copilot-token")

        let request = try #require(networkService.capturedRequest)
        #expect(request.url?.absoluteString == "\(CopilotAPIClient.baseURL)/models")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer copilot-token")
    }

    @Test func fetchModelsFallsBackToDefaultModelOnGarbageResponse() async {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        let body = Data(#"{"unexpected":"shape"}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let models = await CopilotAPIClient.fetchModels(copilotToken: "copilot-token")

        #expect(models == [CopilotAPIClient.defaultModel])
    }

    @Test func fetchModelsFallsBackToDefaultModelOnTransportError() async {
        let networkService = MockNetworkService()
        CopilotAPIClient.networkService = networkService
        networkService.stubSendResponse = .failure(URLError(.notConnectedToInternet))

        let models = await CopilotAPIClient.fetchModels(copilotToken: "copilot-token")

        #expect(models == [CopilotAPIClient.defaultModel])
    }
}
