// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import os
import Testing
import AIProviders
import AICore
import OAuth

/// Tests cover `GeminiAPIClient.enhance` (the non-streaming Cloud Code
/// Assist path that uses `networkService.send`): the outgoing request
/// shape (endpoint, POST method, `Authorization: Bearer` OAuth header,
/// Cloud Code Assist body), success parsing for both the wrapped
/// (`response.candidates`) and raw (`candidates`) shapes, and the
/// status-code / malformed-body error mapping.
///
/// `enhance` passes `Set<Int>.acceptAny` as the acceptable status codes,
/// so `MockNetworkService.validateStatus` never throws on a non-2xx
/// response - the client inspects `httpResponse.statusCode` itself, which
/// is exactly the behavior these tests exercise.
///
/// The streaming paths (`enhanceStreaming`, `chatStreaming`, and `chat`
/// which delegates to `chatStreaming`) all call `networkService.bytes(for:)`,
/// which `MockNetworkService` cannot stub (it throws `StubNotSetError`), so
/// they are intentionally not covered here.
@Suite("GeminiAPIClient", .tags(.networking))
struct GeminiAPIClientTests {

    private let endpoint = "https://cloudcode-pa.googleapis.com/v1internal:generateContent"

    private func makeHTTPResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: endpoint)!,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    /// Builds a Cloud Code Assist success body wrapping the standard Gemini
    /// `candidates -> content -> parts -> text` response under `response`.
    private func wrappedSuccessBody(text: String) -> Data {
        Data(#"""
        {"response":{"candidates":[{"content":{"parts":[{"text":"\#(text)"}]}}]}}
        """#.utf8)
    }

    // MARK: - enhance success

    @Test func enhanceReturnsTrimmedTextFromWrappedResponse() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success(
            (wrappedSuccessBody(text: "  enhanced output  "), makeHTTPResponse(200))
        )

        let result = try await GeminiAPIClient.enhance(
            text: "raw",
            systemPrompt: "system",
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            networkService: networkService
        )

        // Leading/trailing whitespace is trimmed.
        #expect(result == "enhanced output")
    }

    @Test func enhanceParsesUnwrappedCandidatesShape() async throws {
        // Some responses arrive without the Cloud Code Assist `response`
        // wrapper; the client falls back to reading `candidates` at the top
        // level.
        let networkService = MockNetworkService()
        let body = Data(#"{"candidates":[{"content":{"parts":[{"text":"top level"}]}}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let result = try await GeminiAPIClient.enhance(
            text: "raw",
            systemPrompt: "system",
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            networkService: networkService
        )

        #expect(result == "top level")
    }

    // MARK: - request shape

    @Test func enhanceTargetsCloudCodeAssistEndpointWithPost() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success(
            (wrappedSuccessBody(text: "ok"), makeHTTPResponse(200))
        )

        _ = try await GeminiAPIClient.enhance(
            text: "raw",
            systemPrompt: "system",
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            networkService: networkService
        )

        let request = try #require(networkService.capturedRequest)
        #expect(request.url?.absoluteString == endpoint)
        #expect(request.httpMethod == "POST")
    }

    @Test func enhanceSendsOAuthBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success(
            (wrappedSuccessBody(text: "ok"), makeHTTPResponse(200))
        )

        _ = try await GeminiAPIClient.enhance(
            text: "raw",
            systemPrompt: "system",
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            networkService: networkService
        )

        let request = try #require(networkService.capturedRequest)
        // The OAuth access token is transmitted as a Bearer Authorization
        // header (not as an `x-goog-api-key` header or `?key=` query param).
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ya29.token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func enhanceSendsCloudCodeAssistBodyWithPromptAndContents() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success(
            (wrappedSuccessBody(text: "ok"), makeHTTPResponse(200))
        )

        _ = try await GeminiAPIClient.enhance(
            text: "rewrite this",
            systemPrompt: "you are a helper",
            model: "gemini-2.5-pro",
            accessToken: "ya29.token",
            projectId: "proj-123",
            networkService: networkService
        )

        let httpBody = try #require(networkService.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(json["model"] as? String == "gemini-2.5-pro")
        #expect(json["userAgent"] as? String == "vivadicta")
        // projectId, when present, is carried at the top level of the body.
        #expect(json["project"] as? String == "proj-123")

        let nestedRequest = try #require(json["request"] as? [String: Any])

        // The user text becomes the first content part.
        let contents = try #require(nestedRequest["contents"] as? [[String: Any]])
        let firstContent = try #require(contents.first)
        #expect(firstContent["role"] as? String == "user")
        let contentParts = try #require(firstContent["parts"] as? [[String: Any]])
        #expect(contentParts.first?["text"] as? String == "rewrite this")

        // The system prompt becomes the systemInstruction part.
        let systemInstruction = try #require(nestedRequest["systemInstruction"] as? [String: Any])
        let systemParts = try #require(systemInstruction["parts"] as? [[String: Any]])
        #expect(systemParts.first?["text"] as? String == "you are a helper")
    }

    @Test func enhanceOmitsProjectWhenProjectIdNil() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success(
            (wrappedSuccessBody(text: "ok"), makeHTTPResponse(200))
        )

        _ = try await GeminiAPIClient.enhance(
            text: "raw",
            systemPrompt: "system",
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            networkService: networkService
        )

        let httpBody = try #require(networkService.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(json["project"] == nil)
    }

    // MARK: - status-code error mapping

    @Test func enhanceThrowsTokenExchangeFailedOnNon2xx() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"error":"unauthorized"}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(401)))

        let error = try await #require(throws: OAuthError.self) {
            _ = try await GeminiAPIClient.enhance(
                text: "raw",
                systemPrompt: "system",
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                networkService: networkService
            )
        }
        guard case let .tokenExchangeFailed(reason) = error else {
            Issue.record("Expected .tokenExchangeFailed, got \(error)")
            return
        }
        #expect(reason.hasPrefix("HTTP 401"))
    }

    @Test func enhanceMaps429WithoutErrorMessageToRateLimitExceeded() async throws {
        let networkService = MockNetworkService()
        // A 429 body with no parseable `error.message` falls through to the
        // generic rate-limit error.
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(429)))

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await GeminiAPIClient.enhance(
                text: "raw",
                systemPrompt: "system",
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                networkService: networkService
            )
        }
        guard case .rateLimitExceeded = error else {
            Issue.record("Expected .rateLimitExceeded, got \(error)")
            return
        }
    }

    @Test func enhanceMaps429WithErrorMessageToCustomError() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"error":{"message":"quota exceeded for project"}}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(429)))

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await GeminiAPIClient.enhance(
                text: "raw",
                systemPrompt: "system",
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                networkService: networkService
            )
        }
        guard case let .customError(message) = error else {
            Issue.record("Expected .customError, got \(error)")
            return
        }
        #expect(message.contains("quota exceeded for project"))
    }

    // MARK: - malformed success body

    @Test func enhanceThrowsInvalidResponseOnUndecodableBody() async throws {
        let networkService = MockNetworkService()
        // A 200 with a non-JSON body cannot be parsed.
        networkService.stubSendResponse = .success((Data("not json".utf8), makeHTTPResponse(200)))

        let error = try await #require(throws: OAuthError.self) {
            _ = try await GeminiAPIClient.enhance(
                text: "raw",
                systemPrompt: "system",
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                networkService: networkService
            )
        }
        guard case .invalidResponse = error else {
            Issue.record("Expected .invalidResponse, got \(error)")
            return
        }
    }

    @Test func enhanceThrowsInvalidResponseOnEmptyCandidates() async throws {
        let networkService = MockNetworkService()
        // Valid JSON but with no candidates to extract text from.
        let body = Data(#"{"response":{"candidates":[]}}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let error = try await #require(throws: OAuthError.self) {
            _ = try await GeminiAPIClient.enhance(
                text: "raw",
                systemPrompt: "system",
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                networkService: networkService
            )
        }
        guard case .invalidResponse = error else {
            Issue.record("Expected .invalidResponse, got \(error)")
            return
        }
    }
}
