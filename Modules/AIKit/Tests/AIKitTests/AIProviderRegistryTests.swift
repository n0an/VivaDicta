import Testing
import Foundation
import os
import AICore
import AIProviders
import Keychain
import KeychainMocks
import OAuth
import OAuthMocks
import Networking
import NetworkingMocks
@testable import AIKit

/// Verifies `AIProviderRegistry`'s sole responsibility: turning a resolved
/// `AIProviderRoute` + model into a *correctly-configured* `any AITextProvider`.
///
/// The wrappers and underlying services are tested in `AIProvidersTests`; here
/// we assert the registry's config assembly - that the Keychain key / OAuth
/// token / base URL each route needs actually reaches the provider it builds.
/// Where a route's provider has an injectable transport (`MockNetworkService`)
/// we build it then drive `enhance` and inspect the outgoing request; for the
/// OAuth-static clients (OpenAI/Copilot) we assert the token retrieval the
/// registry performs, which is the part it owns.
@MainActor
@Suite("AIProviderRegistry", .tags(.networking))
struct AIProviderRegistryTests {

    private struct TestError: Error {}

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    /// Stores a key under its *real* Keychain key name so the test fails if the
    /// registry looks up the wrong key (the blanket `stubGetString` would hide a
    /// key-name swap by returning the same value for any key).
    private func seed(_ keychain: MockKeychainService, _ value: String, forKey key: String) {
        _ = keychain.save(value, forKey: key)
    }

    private func makeSUT(
        keychain: MockKeychainService = MockKeychainService(),
        oauth: MockOAuthManager = MockOAuthManager(),
        copilot: MockCopilotOAuthManager = MockCopilotOAuthManager(),
        net: MockNetworkService = MockNetworkService()
    ) -> AIProviderRegistry {
        AIProviderRegistry(
            keychain: keychain,
            oauthManager: oauth,
            copilotOAuthManager: copilot,
            networkService: net,
            logger: Logger(subsystem: "test", category: "AIProviderRegistryTests"),
            baseTimeout: 30
        )
    }

    // MARK: - Keychain-keyed routes

    @Test func anthropicRouteBuildsProviderConfiguredWithKeychainKey() async throws {
        let keychain = MockKeychainService()
        seed(keychain, "ANTHROPIC_KEY", forKey: "anthropicAPIKey") // real key name -> catches a key-name swap
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"content":[{"text":"OK"}]}"#.utf8), http(200)))
        let sut = makeSUT(keychain: keychain, net: net)

        let provider = try await sut.makeTextProvider(for: .anthropic, model: "claude-sonnet-4-6")
        _ = try await provider.enhance(systemMessage: "S", userMessage: "U")

        #expect(net.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "x-api-key") == "ANTHROPIC_KEY")
        let body = String(data: net.capturedRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("claude-sonnet-4-6"))   // model bound into the request
    }

    @Test func cloudRouteBuildsBearerKeyedProviderAtProviderBaseURL() async throws {
        let keychain = MockKeychainService()
        seed(keychain, "OPENAI_KEY", forKey: "openAIAPIKey") // real key name -> catches a key-name swap
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"choices":[{"message":{"content":"OK"}}]}"#.utf8), http(200)))
        let sut = makeSUT(keychain: keychain, net: net)

        let provider = try await sut.makeTextProvider(for: .cloud(.openAI), model: "gpt-test")
        _ = try await provider.enhance(systemMessage: "S", userMessage: "U")

        #expect(net.capturedRequest?.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer OPENAI_KEY")
    }

    @Test func missingAPIKeyThrowsNotConfigured() async {
        // Fresh keychain: no stub, no stored value -> getString returns nil.
        let sut = makeSUT()

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.makeTextProvider(for: .anthropic, model: "claude-sonnet-4-6")
        }
    }

    // MARK: - OAuth routes

    @Test func geminiOAuthRouteRetrievesGeminiTokenAndForwardsIt() async throws {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .success((token: "GEM_TOK", accountId: nil, projectId: "proj"))
        let net = MockNetworkService()
        net.stubSendResponse = .failure(URLError(.badServerResponse)) // request is built before the call; response irrelevant
        let sut = makeSUT(oauth: oauth, net: net)

        let provider = try await sut.makeTextProvider(for: .geminiOAuth, model: "gemini-test")
        _ = try? await provider.enhance(systemMessage: "S", userMessage: "U")

        #expect(oauth.validAccessTokenCallCount == 1)
        #expect(oauth.capturedValidAccessTokenProviderKey == "geminiOAuthCredential") // asked for Gemini, not OpenAI
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer GEM_TOK")
    }

    @Test func openAIOAuthRouteRetrievesTokenForOpenAIProvider() async throws {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .success((token: "OAI_TOK", accountId: "acct", projectId: nil))
        let sut = makeSUT(oauth: oauth)

        // OpenAIOAuthClient has an internal transport, so we assert the token
        // retrieval the registry owns rather than the outgoing request.
        _ = try await sut.makeTextProvider(for: .openAIOAuth, model: "gpt-5")

        #expect(oauth.validAccessTokenCallCount == 1)
        #expect(oauth.capturedValidAccessTokenProviderKey == "chatGPTOAuthCredential")
    }

    @Test func oauthRoutePropagatesTokenError() async {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .failure(TestError())
        let sut = makeSUT(oauth: oauth)

        await #expect(throws: TestError.self) {
            _ = try await sut.makeTextProvider(for: .geminiOAuth, model: "gemini-test")
        }
    }

    @Test func copilotRouteRetrievesCopilotToken() async throws {
        let copilot = MockCopilotOAuthManager()
        copilot.stubValidCopilotTokenResponse = .success("ghu_token")
        let sut = makeSUT(copilot: copilot)

        _ = try await sut.makeTextProvider(for: .copilot, model: "gpt-4o")

        #expect(copilot.validCopilotTokenCallCount == 1)
    }

    @Test func copilotRoutePropagatesTokenError() async {
        let copilot = MockCopilotOAuthManager()
        copilot.stubValidCopilotTokenResponse = .failure(TestError())
        let sut = makeSUT(copilot: copilot)

        await #expect(throws: TestError.self) {
            _ = try await sut.makeTextProvider(for: .copilot, model: "gpt-4o")
        }
    }

    // MARK: - Locally-configured endpoint (Ollama / Custom)

    @Test func openAICompatibleEndpointForwardsCallerSuppliedURLAndHeaders() async throws {
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"choices":[{"message":{"content":"OK"}}]}"#.utf8), http(200)))
        let sut = makeSUT(net: net)
        let url = URL(string: "http://localhost:11434/v1/chat/completions")!

        let provider = try await sut.makeTextProvider(
            for: .openAICompatibleEndpoint(
                url: url,
                headers: ["Authorization": "Bearer custom-token"],
                timeout: 120,
                errorPrefix: "Ollama"
            ),
            model: "llama3"
        )
        _ = try await provider.enhance(systemMessage: "S", userMessage: "U")

        #expect(net.capturedRequest?.url == url)                                                  // caller URL, no Keychain lookup
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer custom-token")
        #expect(net.capturedRequest?.timeoutInterval == 120)                                       // caller timeout, not the cloud baseTimeout (300)
    }
}
