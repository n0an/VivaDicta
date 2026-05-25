// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import os
import Testing
@testable import VivaDicta

/// Tests cover `AnthropicService` in isolation: the request shape
/// (`x-api-key`, `anthropic-version`, system top-level, max_tokens
/// required), the status-code mapping, body parsing for the
/// non-OpenAI-compatible `content: [{ text }]` shape, and the
/// API-key verification probe.
///
/// SSE streaming paths can't be fully exercised because
/// `MockNetworkService.bytes(for:)` cannot return a real
/// `URLSession.AsyncBytes`. The streaming tests here verify the
/// outgoing request shape and rely on integration / manual testing
/// for end-to-end SSE parsing.
@Suite("AnthropicService")
struct AnthropicServiceTests {

    private let endpointURL = AIProvider.anthropic.baseURL

    private func makeHTTPResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: endpointURL)!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeSUT(networkService: MockNetworkService) -> AnthropicService {
        AnthropicService(
            networkService: networkService,
            logger: Logger(subsystem: "test", category: "AnthropicServiceTests"),
            baseTimeout: 30
        )
    }

    // MARK: - Request shape (non-streaming)

    @Test func enhanceSendsXAPIKeyHeaderNotBearer() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"content":[{"text":"ok"}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = try await sut.enhance(
            systemMessage: "system",
            userMessage: "hello",
            apiKey: "sk-ant-test",
            model: "claude-sonnet-4-5"
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        // Anthropic does not use Bearer auth.
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func enhanceSendsAnthropicMessagesBodyShape() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"content":[{"text":"ok"}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = try await sut.enhance(
            systemMessage: "you are a helper",
            userMessage: "rewrite this",
            apiKey: "sk-ant-test",
            model: "claude-opus-4-7"
        )

        let httpBody = try #require(networkService.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(json["model"] as? String == "claude-opus-4-7")
        #expect(json["max_tokens"] as? Int == 8192)
        // System is top-level, NOT a message in the messages array.
        #expect(json["system"] as? String == "you are a helper")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "rewrite this"]])
    }

    // MARK: - Non-streaming success/error mapping

    @Test func enhanceReturnsTextFromAnthropicContentArray() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"content":[{"type":"text","text":"  enhanced output  "}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        let result = try await sut.enhance(
            systemMessage: "system",
            userMessage: "user",
            apiKey: "sk-ant-test",
            model: "claude-sonnet-4-5"
        )

        // Whitespace is trimmed and the output filter is applied.
        #expect(result == "enhanced output")
    }

    @Test func enhanceThrowsEnhancementFailedOnMalformedBody() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"unexpected":"shape"}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.enhance(
                systemMessage: "system",
                userMessage: "user",
                apiKey: "sk-ant-test",
                model: "claude-sonnet-4-5"
            )
        }
    }

    @Test func enhanceMaps429ToRateLimitExceeded() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(429)))
        let sut = makeSUT(networkService: networkService)

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await sut.enhance(
                systemMessage: "s",
                userMessage: "u",
                apiKey: "k",
                model: "m"
            )
        }
        guard case .rateLimitExceeded = error else {
            Issue.record("Expected .rateLimitExceeded, got \(error)")
            return
        }
    }

    @Test func enhanceMaps5xxToServerError() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(503)))
        let sut = makeSUT(networkService: networkService)

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await sut.enhance(
                systemMessage: "s",
                userMessage: "u",
                apiKey: "k",
                model: "m"
            )
        }
        guard case .serverError = error else {
            Issue.record("Expected .serverError, got \(error)")
            return
        }
    }

    @Test func enhanceMapsOtherStatusToCustomError() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"error":{"message":"bad model"}}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(400)))
        let sut = makeSUT(networkService: networkService)

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await sut.enhance(
                systemMessage: "s",
                userMessage: "u",
                apiKey: "k",
                model: "m"
            )
        }
        guard case let .customError(message) = error else {
            Issue.record("Expected .customError, got \(error)")
            return
        }
        #expect(message.hasPrefix("HTTP 400"))
    }

    // MARK: - verifyAPIKey

    @Test func verifyAPIKeyReturnsTrueOn200() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        let valid = await sut.verifyAPIKey("sk-ant-test")

        #expect(valid)
    }

    @Test func verifyAPIKeyReturnsFalseOn401() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(401)))
        let sut = makeSUT(networkService: networkService)

        let valid = await sut.verifyAPIKey("sk-ant-bad")

        #expect(valid == false)
    }

    @Test func verifyAPIKeyReturnsFalseOnTransportError() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(URLError(.notConnectedToInternet))
        let sut = makeSUT(networkService: networkService)

        let valid = await sut.verifyAPIKey("sk-ant-test")

        #expect(valid == false)
    }

    @Test func verifyAPIKeySendsCorrectHeadersAndBody() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = await sut.verifyAPIKey("sk-ant-test")

        let request = try #require(networkService.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == AIProvider.anthropic.defaultModel)
        #expect(json["max_tokens"] as? Int == 1024)
        #expect(json["system"] as? String == "You are a test system.")
    }

    // MARK: - Streaming request shape
    //
    // `MockNetworkService.bytes(for:)` cannot return a real
    // `URLSession.AsyncBytes`, so it throws `StubNotSetError` before any
    // SSE bytes are yielded. We can still verify the outgoing request
    // shape (headers, body) - the SSE parser itself is covered by
    // integration / manual testing.

    @Test func enhanceStreamingSendsCorrectHeadersAndStreamingBody() async throws {
        let networkService = MockNetworkService()
        let sut = makeSUT(networkService: networkService)

        _ = try? await sut.enhanceStreaming(
            systemMessage: "you are a helper",
            userMessage: "stream this",
            apiKey: "sk-ant-stream",
            model: "claude-sonnet-4-5",
            onPartialResponse: { _ in }
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-stream")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["stream"] as? Bool == true)
        #expect(json["model"] as? String == "claude-sonnet-4-5")
        #expect(json["max_tokens"] as? Int == 8192)
        #expect(json["system"] as? String == "you are a helper")
    }
}
