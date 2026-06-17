import Testing
import Foundation
import Networking
import NetworkingMocks
import os
import AIProviders

/// Smoke tests proving the thin `AITextProvider` wrappers delegate end-to-end
/// (bind config + forward system/user message + return the parsed result)
/// through a mocked transport. The per-provider request/parse logic is covered
/// by each service's own test suite; the wrappers' job is config binding and
/// naming normalization.
@Suite("AITextProvider wrappers", .tags(.networking))
struct TextProvidersTests {

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func logger() -> Logger { Logger(subsystem: "test", category: "TextProvidersTests") }

    @Test func anthropicWrapperForwardsMessagesAndReturnsEnhancedText() async throws {
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"content":[{"text":"ENHANCED"}]}"#.utf8), http(200)))

        let sut = AnthropicTextProvider(
            networkService: net, logger: logger(), baseTimeout: 30,
            apiKey: "sk-test", model: "claude-sonnet-4-6"
        )
        let result = try await sut.enhance(systemMessage: "SYSMARK", userMessage: "USRMARK")

        #expect(result == "ENHANCED")
        let body = String(data: net.capturedRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("SYSMARK"))   // system message reached the request
        #expect(body.contains("USRMARK"))   // user message reached the request
    }

    @Test func openAICompatibleWrapperForwardsMessagesAndReturnsEnhancedText() async throws {
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"choices":[{"message":{"content":"ENHANCED"}}]}"#.utf8), http(200)))

        let sut = OpenAICompatibleTextProvider(
            networkService: net, logger: logger(),
            url: URL(string: "https://api.example.com/v1/chat/completions")!,
            modelName: "gpt-test", headers: ["Authorization": "Bearer x"], timeout: 30,
            errorPrefix: "Example"
        )
        let result = try await sut.enhance(systemMessage: "SYSMARK", userMessage: "USRMARK")

        #expect(result == "ENHANCED")
        let body = String(data: net.capturedRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("SYSMARK"))
        #expect(body.contains("USRMARK"))
    }
}
