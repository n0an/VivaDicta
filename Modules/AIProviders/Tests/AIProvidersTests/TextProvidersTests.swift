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

    /// Regression guard for the OAuth naming map: GeminiTextProvider must place
    /// `systemMessage` in Gemini's `systemInstruction` slot and `userMessage` in
    /// the user `contents` slot. A swap would compile cleanly and silently send
    /// the user's text as the system prompt - this pins it. (Gemini is the one
    /// OAuth client with an injectable transport, so it's the cheap one to lock.)
    @Test func geminiWrapperMapsSystemMessageToSystemInstructionAndUserMessageToContents() async {
        let net = MockNetworkService()
        net.stubSendResponse = .failure(URLError(.badServerResponse)) // response irrelevant; assert the request
        let sut = GeminiTextProvider(model: "gemini-test", accessToken: "tok", projectId: nil, networkService: net)

        _ = try? await sut.enhance(systemMessage: "SYSMARK", userMessage: "USRMARK")

        let json = try? JSONSerialization.jsonObject(with: net.capturedRequest?.httpBody ?? Data()) as? [String: Any]
        let request = json?["request"] as? [String: Any]
        let systemText = ((request?["systemInstruction"] as? [String: Any])?["parts"] as? [[String: Any]])?.first?["text"] as? String
        let userText = ((request?["contents"] as? [[String: Any]])?.first?["parts"] as? [[String: Any]])?.first?["text"] as? String

        #expect(systemText == "SYSMARK", "systemMessage must map to Gemini systemInstruction")
        #expect(userText == "USRMARK", "userMessage must map to Gemini user contents")
    }
}
