// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import Testing
import AIProviders
import AICore
import OAuth

/// Pure, network-free helpers on `GeminiAPIClient`. These need no session at
/// all, so they stay outside the serialized streaming suite and run in
/// parallel.
@Suite("GeminiAPIClient helpers", .tags(.networking))
struct GeminiAPIClientHelperTests {

    @Test func resolveModelFallsBackToDefaultWhenEmpty() {
        #expect(GeminiAPIClient.resolveModel("") == GeminiAPIClient.defaultModel)
    }

    @Test func resolveModelKeepsExplicitModel() {
        #expect(GeminiAPIClient.resolveModel("gemini-2.5-pro") == "gemini-2.5-pro")
    }

    @Test func streamingTextReadsCloudCodeAssistWrappedCandidate() {
        let event: [String: Any] = ["response": ["candidates": [["content": ["parts": [["text": "abc"]]]]]]]
        #expect(GeminiAPIClient.streamingText(from: event) == "abc")
    }

    @Test func streamingTextReadsUnwrappedCandidate() {
        let event: [String: Any] = ["candidates": [["content": ["parts": [["text": "xyz"]]]]]]
        #expect(GeminiAPIClient.streamingText(from: event) == "xyz")
    }

    @Test func streamingTextJoinsMultipleParts() {
        let event: [String: Any] = ["candidates": [["content": ["parts": [["text": "a"], ["text": "b"]]]]]]
        #expect(GeminiAPIClient.streamingText(from: event) == "ab")
    }

    @Test func streamingTextReturnsNilWhenNoCandidates() {
        #expect(GeminiAPIClient.streamingText(from: ["foo": "bar"]) == nil)
    }

    @Test func streamingTextReturnsNilWhenPartsEmpty() {
        let event: [String: Any] = ["candidates": [["content": ["parts": []]]]]
        #expect(GeminiAPIClient.streamingText(from: event) == nil)
    }
}

/// Collects the `@MainActor`-isolated partial-response callbacks so tests can
/// assert that streaming delivered incremental deltas, not just a final value.
@MainActor
final class PartialSink {
    private(set) var values: [String] = []
    func receive(_ value: String) { values.append(value) }
}

/// Drives `GeminiAPIClient`'s SSE streaming paths (`chatStreaming`, `chat`,
/// `enhanceStreaming`) end-to-end against a real `URLSession` whose transport
/// is the `StreamingURLProtocol` stub. Serialized because the stub is shared
/// static state.
@MainActor
@Suite("GeminiAPIClient streaming", .tags(.networking), .serialized)
struct GeminiAPIClientStreamingTests {

    /// One Cloud Code Assist SSE event carrying `text` under the standard
    /// `candidates -> content -> parts` shape, optionally wrapped under
    /// `response` as the Cloud Code Assist endpoint does.
    private func candidateEvent(_ text: String, wrapped: Bool = true) -> String {
        let inner = "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"\(text)\"}]}}]}"
        return wrapped ? "{\"response\":\(inner)}" : inner
    }

    /// Joins JSON events as `data: <json>` lines. `chatStreaming` parses each
    /// `data:` line eagerly, so multiple deltas stream correctly here.
    /// `enhanceStreaming` instead buffers until a blank-line delimiter (which
    /// `AsyncBytes.lines` does not surface from back-to-back newlines), so its
    /// test below uses a single complete event rather than multiple deltas.
    private func sse(_ events: [String]) -> Data {
        Data(events.map { "data: \($0)" }.joined(separator: "\n").utf8)
    }

    private func userMessages() -> [[String: String]] {
        [["role": "user", "content": "hi"]]
    }

    // MARK: - chatStreaming

    @Test func chatStreamingAggregatesSSEDeltasAndStreamsPartials() async throws {
        StreamingURLProtocol.stub = .init(
            statusCode: 200,
            body: sse([candidateEvent("Hello"), candidateEvent("Hello world")])
        )
        let sink = PartialSink()

        let result = try await GeminiAPIClient.chatStreaming(
            systemMessage: "system",
            messages: userMessages(),
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            onPartialResponse: { sink.receive($0) },
            networkService: StreamingURLProtocol.makeNetworkService()
        )

        #expect(result.contains("Hello world"))
        // Incremental deltas were surfaced as they arrived, not just the final.
        #expect(sink.values.contains("Hello"))
        #expect(sink.values.contains("Hello world"))
    }

    @Test func chatStreamingThrowsInvalidResponseWhenNoTextEventsArrive() async throws {
        // Valid SSE framing but every event lacks extractable text.
        StreamingURLProtocol.stub = .init(
            statusCode: 200,
            body: sse(["{\"response\":{\"candidates\":[]}}"])
        )

        let error = try await #require(throws: OAuthError.self) {
            _ = try await GeminiAPIClient.chatStreaming(
                systemMessage: "system",
                messages: userMessages(),
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                onPartialResponse: { _ in },
                networkService: StreamingURLProtocol.makeNetworkService()
            )
        }
        guard case .invalidResponse = error else {
            Issue.record("Expected .invalidResponse, got \(error)")
            return
        }
    }

    @Test func chatStreamingMapsServerErrorOn5xx() async throws {
        StreamingURLProtocol.stub = .init(statusCode: 503, body: Data("upstream boom".utf8))

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await GeminiAPIClient.chatStreaming(
                systemMessage: "system",
                messages: userMessages(),
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                onPartialResponse: { _ in },
                networkService: StreamingURLProtocol.makeNetworkService()
            )
        }
        guard case .serverError = error else {
            Issue.record("Expected .serverError, got \(error)")
            return
        }
    }

    @Test func chatStreamingMaps429WithMessageToCustomError() async throws {
        StreamingURLProtocol.stub = .init(
            statusCode: 429,
            body: Data("{\"error\":{\"message\":\"quota exceeded\"}}".utf8)
        )

        let error = try await #require(throws: EnhancementError.self) {
            _ = try await GeminiAPIClient.chatStreaming(
                systemMessage: "system",
                messages: userMessages(),
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                onPartialResponse: { _ in },
                networkService: StreamingURLProtocol.makeNetworkService()
            )
        }
        guard case let .customError(message) = error else {
            Issue.record("Expected .customError, got \(error)")
            return
        }
        #expect(message.contains("quota exceeded"))
    }

    @Test func chatStreamingMapsAuthFailureToTokenExchangeFailed() async throws {
        StreamingURLProtocol.stub = .init(statusCode: 401, body: Data("{\"error\":\"unauthorized\"}".utf8))

        let error = try await #require(throws: OAuthError.self) {
            _ = try await GeminiAPIClient.chatStreaming(
                systemMessage: "system",
                messages: userMessages(),
                model: "gemini-3.5-flash",
                accessToken: "ya29.token",
                projectId: nil,
                onPartialResponse: { _ in },
                networkService: StreamingURLProtocol.makeNetworkService()
            )
        }
        guard case let .tokenExchangeFailed(reason) = error else {
            Issue.record("Expected .tokenExchangeFailed, got \(error)")
            return
        }
        #expect(reason.hasPrefix("HTTP 401"))
    }

    // MARK: - chat (non-streaming wrapper over chatStreaming)

    @Test func chatBuffersStreamingHelperAndReturnsAggregate() async throws {
        StreamingURLProtocol.stub = .init(
            statusCode: 200,
            body: sse([candidateEvent("Buffered reply")])
        )

        let result = try await GeminiAPIClient.chat(
            systemMessage: "system",
            messages: userMessages(),
            model: "", // exercises resolveModel's empty -> default fallback
            accessToken: "ya29.token",
            projectId: "proj-123",
            networkService: StreamingURLProtocol.makeNetworkService()
        )

        #expect(result.contains("Buffered reply"))
    }

    // MARK: - enhanceStreaming

    @Test func enhanceStreamingParsesEventAndReturnsFinalText() async throws {
        StreamingURLProtocol.stub = .init(
            statusCode: 200,
            body: sse([candidateEvent("Refined text")])
        )
        let sink = PartialSink()

        let result = try await GeminiAPIClient.enhanceStreaming(
            text: "raw",
            systemPrompt: "system",
            model: "gemini-3.5-flash",
            accessToken: "ya29.token",
            projectId: nil,
            onPartialResult: { sink.receive($0) },
            networkService: StreamingURLProtocol.makeNetworkService()
        )

        #expect(result.contains("Refined text"))
        #expect(sink.values.contains("Refined text"))
    }
}
