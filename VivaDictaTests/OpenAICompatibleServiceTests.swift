// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import os
import Testing
@testable import VivaDicta

/// Tests cover `OpenAICompatibleService` in isolation: the static body
/// builder and SSE delta parser (pure functions, fully exercised),
/// the instance `enhance` non-streaming path (success, 429, 5xx,
/// other, malformed body, request shape), the instance
/// `verifyChatCompletionsAPIKey` probe, and the streaming request
/// shape (full SSE parsing is not testable via MockNetworkService;
/// see the comment near the streaming tests).
@Suite("OpenAICompatibleService")
struct OpenAICompatibleServiceTests {

    private let endpointURL = "https://api.example.com/v1/chat/completions"

    private func makeHTTPResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: endpointURL)!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeSUT(networkService: MockNetworkService) -> OpenAICompatibleService {
        OpenAICompatibleService(
            networkService: networkService,
            logger: Logger(subsystem: "test", category: "OpenAICompatibleServiceTests")
        )
    }

    // MARK: - Static buildRequestBody

    @Test func buildRequestBodyIncludesStandardFields() throws {
        let body = OpenAICompatibleService.buildRequestBody(
            modelName: "gpt-4",
            systemMessage: "you are a helper",
            userMessage: "rewrite this",
            stream: false
        )

        #expect(body["model"] as? String == "gpt-4")
        #expect(body["stream"] as? Bool == false)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages == [
            ["role": "system", "content": "you are a helper"],
            ["role": "user", "content": "rewrite this"]
        ])
    }

    @Test func buildRequestBodyIncludesTemperatureForNonGPT5() {
        let body = OpenAICompatibleService.buildRequestBody(
            modelName: "gpt-4",
            systemMessage: "s",
            userMessage: "u",
            stream: false
        )

        #expect(body["temperature"] as? Double == 0.3)
    }

    @Test func buildRequestBodyOmitsTemperatureForGPT5() {
        let body = OpenAICompatibleService.buildRequestBody(
            modelName: "gpt-5-mini",
            systemMessage: "s",
            userMessage: "u",
            stream: false
        )

        #expect(body["temperature"] == nil)
    }

    @Test func buildRequestBodyOmitsTemperatureForUppercaseGPT5() {
        // The check is case-insensitive (`.lowercased().hasPrefix("gpt-5")`).
        let body = OpenAICompatibleService.buildRequestBody(
            modelName: "GPT-5-Mini",
            systemMessage: "s",
            userMessage: "u",
            stream: false
        )

        #expect(body["temperature"] == nil)
    }

    @Test func buildRequestBodyPassesStreamFlag() {
        let streamingBody = OpenAICompatibleService.buildRequestBody(
            modelName: "gpt-4",
            systemMessage: "s",
            userMessage: "u",
            stream: true
        )

        #expect(streamingBody["stream"] as? Bool == true)
    }

    // MARK: - Static streamingDelta

    @Test func streamingDeltaIgnoresNonDataLines() {
        #expect(OpenAICompatibleService.streamingDelta(from: "event: ping") == nil)
        #expect(OpenAICompatibleService.streamingDelta(from: "") == nil)
    }

    @Test func streamingDeltaIgnoresDoneSentinel() {
        #expect(OpenAICompatibleService.streamingDelta(from: "data: [DONE]") == nil)
    }

    @Test func streamingDeltaIgnoresMalformedJSON() {
        #expect(OpenAICompatibleService.streamingDelta(from: "data: not-json") == nil)
    }

    @Test func streamingDeltaExtractsStringContent() {
        let line = #"data: {"choices":[{"delta":{"content":"hello"}}]}"#
        #expect(OpenAICompatibleService.streamingDelta(from: line) == "hello")
    }

    @Test func streamingDeltaExtractsArrayContent() {
        let line = #"data: {"choices":[{"delta":{"content":[{"text":"foo"},{"text":"bar"}]}}]}"#
        #expect(OpenAICompatibleService.streamingDelta(from: line) == "foobar")
    }

    @Test func streamingDeltaExtractsLegacyTextField() {
        let line = #"data: {"choices":[{"text":"legacy"}]}"#
        #expect(OpenAICompatibleService.streamingDelta(from: line) == "legacy")
    }

    @Test func streamingDeltaReturnsNilForEmptyContent() {
        let line = #"data: {"choices":[{"delta":{"content":""}}]}"#
        #expect(OpenAICompatibleService.streamingDelta(from: line) == nil)
    }

    // MARK: - enhance non-streaming success

    @Test func enhanceReturnsTextFromChoicesArray() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"choices":[{"message":{"content":"  enhanced output  "}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        let result = try await sut.enhance(
            url: URL(string: endpointURL)!,
            modelName: "gpt-4",
            systemMessage: "s",
            userMessage: "u",
            headers: ["Authorization": "Bearer sk-test"],
            timeout: 30
        )

        // Whitespace is trimmed and output filter is applied.
        #expect(result == "enhanced output")
    }

    @Test func enhanceSendsBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = try await sut.enhance(
            url: URL(string: endpointURL)!,
            modelName: "gpt-4",
            systemMessage: "s",
            userMessage: "u",
            headers: ["Authorization": "Bearer sk-test"],
            timeout: 30
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func enhanceSendsChatCompletionsBody() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = try await sut.enhance(
            url: URL(string: endpointURL)!,
            modelName: "gpt-4",
            systemMessage: "you are helpful",
            userMessage: "rewrite this",
            headers: [:],
            timeout: 30
        )

        let httpBody = try #require(networkService.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(json["model"] as? String == "gpt-4")
        #expect(json["stream"] as? Bool == false)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [
            ["role": "system", "content": "you are helpful"],
            ["role": "user", "content": "rewrite this"]
        ])
    }

    // MARK: - enhance error mapping

    @Test func enhanceThrowsEnhancementFailedOnMalformedBody() async {
        let networkService = MockNetworkService()
        let body = Data(#"{"unexpected":"shape"}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.enhance(
                url: URL(string: self.endpointURL)!,
                modelName: "gpt-4",
                systemMessage: "s",
                userMessage: "u",
                headers: [:],
                timeout: 30
            )
        }
    }

    @Test func enhanceMaps429ToRateLimitExceeded() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(429)))
        let sut = makeSUT(networkService: networkService)

        do {
            _ = try await sut.enhance(
                url: URL(string: endpointURL)!,
                modelName: "m",
                systemMessage: "s",
                userMessage: "u",
                headers: [:],
                timeout: 30
            )
            Issue.record("Expected rateLimitExceeded")
        } catch let error as EnhancementError {
            if case .rateLimitExceeded = error {} else {
                Issue.record("Expected .rateLimitExceeded, got \(error)")
            }
        } catch {
            Issue.record("Expected EnhancementError, got \(error)")
        }
    }

    @Test func enhanceMaps5xxToServerError() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(502)))
        let sut = makeSUT(networkService: networkService)

        do {
            _ = try await sut.enhance(
                url: URL(string: endpointURL)!,
                modelName: "m",
                systemMessage: "s",
                userMessage: "u",
                headers: [:],
                timeout: 30
            )
            Issue.record("Expected serverError")
        } catch let error as EnhancementError {
            if case .serverError = error {} else {
                Issue.record("Expected .serverError, got \(error)")
            }
        } catch {
            Issue.record("Expected EnhancementError, got \(error)")
        }
    }

    @Test func enhanceRethrowsURLErrorTransport() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(URLError(.timedOut))
        let sut = makeSUT(networkService: networkService)

        do {
            _ = try await sut.enhance(
                url: URL(string: endpointURL)!,
                modelName: "m",
                systemMessage: "s",
                userMessage: "u",
                headers: [:],
                timeout: 30
            )
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        } catch {
            Issue.record("Expected URLError, got \(error)")
        }
    }

    @Test func enhanceMapsOtherStatusToCustomError() async {
        let networkService = MockNetworkService()
        let body = Data(#"{"error":"unauthorized"}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(401)))
        let sut = makeSUT(networkService: networkService)

        do {
            _ = try await sut.enhance(
                url: URL(string: endpointURL)!,
                modelName: "m",
                systemMessage: "s",
                userMessage: "u",
                headers: [:],
                timeout: 30
            )
            Issue.record("Expected customError")
        } catch let error as EnhancementError {
            if case let .customError(message) = error {
                #expect(message.hasPrefix("HTTP 401"))
            } else {
                Issue.record("Expected .customError, got \(error)")
            }
        } catch {
            Issue.record("Expected EnhancementError, got \(error)")
        }
    }

    // MARK: - verifyChatCompletionsAPIKey

    @Test func verifyChatCompletionsAPIKeyReturnsTrueOn200() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        let valid = await sut.verifyChatCompletionsAPIKey(
            "sk-test",
            baseURL: endpointURL,
            defaultModel: "gpt-4",
            providerName: "openai"
        )

        #expect(valid)
    }

    @Test func verifyChatCompletionsAPIKeyReturnsFalseOn401() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(401)))
        let sut = makeSUT(networkService: networkService)

        let valid = await sut.verifyChatCompletionsAPIKey(
            "sk-bad",
            baseURL: endpointURL,
            defaultModel: "gpt-4",
            providerName: "openai"
        )

        #expect(!valid)
    }

    @Test func verifyChatCompletionsAPIKeyReturnsFalseOnTransportError() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(URLError(.notConnectedToInternet))
        let sut = makeSUT(networkService: networkService)

        let valid = await sut.verifyChatCompletionsAPIKey(
            "sk-test",
            baseURL: endpointURL,
            defaultModel: "gpt-4",
            providerName: "openai"
        )

        #expect(!valid)
    }

    @Test func verifyChatCompletionsAPIKeySendsBearerAndMinimalBody() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = await sut.verifyChatCompletionsAPIKey(
            "sk-probe",
            baseURL: endpointURL,
            defaultModel: "gpt-4-mini",
            providerName: "openai"
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-probe")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "gpt-4-mini")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "test"]])
    }

    // MARK: - Streaming request shape
    //
    // `MockNetworkService.bytes(for:)` cannot return a real
    // `URLSession.AsyncBytes`, so it throws `StubNotSetError` before any
    // SSE bytes are yielded. We can still verify the outgoing request
    // shape (headers, body, stream flag) - the SSE parser itself is
    // exercised by the static `streamingDelta(from:)` tests above.

    @Test func enhanceStreamingSendsCorrectHeadersAndBody() async throws {
        let networkService = MockNetworkService()
        let sut = makeSUT(networkService: networkService)

        _ = try? await sut.enhanceStreaming(
            url: URL(string: endpointURL)!,
            modelName: "gpt-4",
            systemMessage: "s",
            userMessage: "u",
            headers: ["Authorization": "Bearer sk-stream"],
            timeout: 60,
            errorPrefix: "test",
            onPartialResponse: { _ in }
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-stream")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["stream"] as? Bool == true)
        #expect(json["model"] as? String == "gpt-4")
    }
}
