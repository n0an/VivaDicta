// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Keychain
import KeychainMocks
import Networking
import NetworkingMocks
import OAuth
import OAuthMocks
import Presets
import Testing
import AICore
import AIKit
@testable import VivaDicta

/// Test double for the CLI-server boundary. `@MainActor` to satisfy the
/// `@MainActor` protocol. Records the `enhance` call so tests can assert the
/// orchestration routed through the CLI server (previously untestable, since
/// the orchestration reached `VivAgentsClient` statics directly).
@MainActor
private final class MockCLIServerEnhancer: CLIServerEnhancer {
    var activeProviders: Set<CLIServerProvider> = []
    var serverURL: String?
    var stubEnhanceResult = ""
    private(set) var enhanceCallCount = 0
    private(set) var capturedProvider: CLIServerProvider?

    func isCliActive(for provider: CLIServerProvider) -> Bool { activeProviders.contains(provider) }

    func enhance(text: String, systemPrompt: String, model: String, provider: CLIServerProvider) async throws -> String {
        enhanceCallCount += 1
        capturedProvider = provider
        return stubEnhanceResult
    }
}

/// Characterization tests for `AIService`'s enhancement routing.
///
/// They pin the outgoing request for each route through `AIService`'s injected
/// dependencies (`KeychainService` / `OAuthManager` / `NetworkService`), so the
/// Phase 11 move to `AIProviderRegistry` is provably behavior-preserving: the
/// same request must still reach the same endpoint carrying the same credential.
///
/// The Keychain-keyed cloud routes became drivable here once the registry
/// (reading the injected `KeychainService`) became the single source of the
/// API-key precondition - before that, `AIService`'s guard read the file-private
/// `DefaultKeychainService`, which a mock couldn't reach.
@Suite(.tags(.networking))
@MainActor
struct AIServiceEnhanceRoutingTests {

    private let suiteName = "AIServiceEnhanceRoutingTests.\(UUID().uuidString)"

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeMode(aiProvider: AIProvider, aiModel: String) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "Routing Test Mode",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test-whisper",
            presetId: "regular",
            aiProvider: aiProvider,
            aiModel: aiModel,
            aiEnhanceEnabled: true
        )
    }

    /// Gemini OAuth is the one non-streaming route whose entire transport is
    /// injectable (OAuth token via the mock manager, request via the mock
    /// network), so it can pin the wiring end-to-end: signed-in Gemini must
    /// fetch the *Gemini* OAuth token and send it to the cloudcode endpoint.
    @Test func geminiOAuthRouteSendsOAuthTokenToCloudCodeEndpoint() async {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .success((token: "GEM_TOKEN", accountId: nil, projectId: "proj-1"))
        let net = MockNetworkService()
        net.stubSendResponse = .failure(URLError(.badServerResponse)) // request is captured before the call; response irrelevant

        let sut = AIService(
            userDefaults: makeDefaults(),
            networkService: net,
            oauthManager: oauth
        )
        sut.isGeminiSignedIn = true
        let mode = makeMode(aiProvider: .gemini, aiModel: "gemini-3-flash-preview")

        _ = try? await sut.generateVariation(text: "hello world", preset: PresetCatalog.regular, modeOverride: mode)

        #expect(oauth.capturedValidAccessTokenProviderKey == "geminiOAuthCredential")   // Gemini OAuth, not OpenAI
        #expect(net.capturedRequest?.url?.absoluteString.contains("cloudcode-pa.googleapis.com") == true)
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer GEM_TOKEN")
    }

    /// Streaming counterpart: passing an `onPartialResult` to a signed-in Gemini
    /// mode routes through `makeStreamingRequest`'s `.geminiOAuth` case, which
    /// must still fetch the Gemini OAuth token and stream from the cloudcode
    /// streaming endpoint with that token.
    @Test func geminiOAuthStreamingRouteSendsOAuthTokenToCloudCodeEndpoint() async {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .success((token: "GEM_STREAM_TOKEN", accountId: nil, projectId: "proj-1"))
        let net = MockNetworkService()
        net.stubSendResponse = .failure(URLError(.badServerResponse)) // request is captured before the call; response irrelevant

        let sut = AIService(
            userDefaults: makeDefaults(),
            networkService: net,
            oauthManager: oauth
        )
        sut.isGeminiSignedIn = true
        let mode = makeMode(aiProvider: .gemini, aiModel: "gemini-3-flash-preview")

        _ = try? await sut.generateVariation(
            text: "hello world",
            preset: PresetCatalog.regular,
            modeOverride: mode,
            onPartialResult: { _ in }
        )

        #expect(oauth.capturedValidAccessTokenProviderKey == "geminiOAuthCredential")
        #expect(net.capturedRequest?.url?.absoluteString.contains("cloudcode-pa.googleapis.com") == true)
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer GEM_STREAM_TOKEN")
    }

    // MARK: - Keychain-keyed cloud routes
    //
    // Drivable now that the registry (reading the injected KeychainService) is
    // the single source of the API-key precondition. A fresh MockOAuthManager
    // reports "not signed in", so these modes take the cloud path, not OAuth.

    @Test func cloudRouteSendsBearerKeyToProviderEndpoint() async throws {
        let keychain = MockKeychainService()
        _ = keychain.save("OPENAI_KEY", forKey: "openAIAPIKey")
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"choices":[{"message":{"content":"OK"}}]}"#.utf8), http(200)))

        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: keychain,
            networkService: net,
            oauthManager: MockOAuthManager()
        )
        let mode = makeMode(aiProvider: .openAI, aiModel: "gpt-test")

        _ = try await sut.generateVariation(text: "hello world", preset: PresetCatalog.regular, modeOverride: mode)

        #expect(net.capturedRequest?.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer OPENAI_KEY")
    }

    @Test func anthropicCloudRouteSendsApiKeyHeaderToMessagesEndpoint() async throws {
        let keychain = MockKeychainService()
        _ = keychain.save("ANTHROPIC_KEY", forKey: "anthropicAPIKey")
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"content":[{"type":"text","text":"OK"}]}"#.utf8), http(200)))

        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: keychain,
            networkService: net,
            oauthManager: MockOAuthManager()
        )
        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6")

        _ = try await sut.generateVariation(text: "hello world", preset: PresetCatalog.regular, modeOverride: mode)

        #expect(net.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "x-api-key") == "ANTHROPIC_KEY")
    }

    /// The registry is now the single source of the API-key precondition: with no
    /// key in the (injected) Keychain, the cloud route throws `.notConfigured`.
    @Test func cloudRouteThrowsNotConfiguredWhenKeyMissing() async {
        let net = MockNetworkService()
        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: MockKeychainService(),   // empty - no key
            networkService: net,
            oauthManager: MockOAuthManager()
        )
        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6")

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.generateVariation(text: "hello world", preset: PresetCatalog.regular, modeOverride: mode)
        }
        #expect(net.capturedRequest == nil)   // failed the precondition before any network call
    }

    /// Streaming counterpart of the Anthropic cloud route - covers the streaming
    /// `.anthropic` guard removal. `MockNetworkService.bytes` can't return a
    /// stubbed `AsyncBytes`, but it captures the request before throwing, so we
    /// can still assert the request reached `/v1/messages` with the `x-api-key`.
    @Test func anthropicStreamingCloudRouteSendsApiKeyHeaderToMessagesEndpoint() async {
        let keychain = MockKeychainService()
        _ = keychain.save("ANTHROPIC_STREAM_KEY", forKey: "anthropicAPIKey")
        let net = MockNetworkService()

        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: keychain,
            networkService: net,
            oauthManager: MockOAuthManager()
        )
        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6")

        _ = try? await sut.generateVariation(
            text: "hello world",
            preset: PresetCatalog.regular,
            modeOverride: mode,
            onPartialResult: { _ in }
        )

        #expect(net.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "x-api-key") == "ANTHROPIC_STREAM_KEY")
    }

    /// Ollama streams via the `.openAICompatibleEndpoint` route, which must carry
    /// the caller's server URL, the local-inference timeout (120s, not the cloud
    /// 300s), and no auth header. `MockNetworkService.bytes` captures the request
    /// before throwing, so the route config is assertable.
    @Test func ollamaStreamingRouteSendsToServerEndpointWithLocalTimeout() async {
        let net = MockNetworkService()
        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: MockKeychainService(),
            networkService: net,
            oauthManager: MockOAuthManager()
        )
        sut.ollamaServerURL = "http://localhost:11434"
        let mode = makeMode(aiProvider: .ollama, aiModel: "llama3")

        _ = try? await sut.generateVariation(
            text: "hello world",
            preset: PresetCatalog.regular,
            modeOverride: mode,
            onPartialResult: { _ in }
        )

        #expect(net.capturedRequest?.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
        #expect(net.capturedRequest?.timeoutInterval == 120)                              // local-inference timeout from the route
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)   // Ollama needs no auth
    }

    /// When the Anthropic CLI server is active, the non-streaming orchestration
    /// routes through the injected `CLIServerEnhancer` (not the registry/network).
    /// This path was untestable before the CLI seam - it reached `VivAgentsClient`
    /// statics directly.
    @Test func anthropicCliServerRouteEnhancesViaCliServerEnhancer() async throws {
        let cli = MockCLIServerEnhancer()
        cli.activeProviders = [.anthropic]
        cli.serverURL = "http://mac.local:4000"
        cli.stubEnhanceResult = "CLI_RESULT"

        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: MockKeychainService(),
            networkService: MockNetworkService(),
            oauthManager: MockOAuthManager(),
            cliServerEnhancer: cli
        )
        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6")

        let (result, _) = try await sut.generateVariation(text: "hi", preset: PresetCatalog.regular, modeOverride: mode)

        #expect(cli.enhanceCallCount == 1)
        #expect(cli.capturedProvider == .anthropic)   // routed to the Anthropic CLI backend
        #expect(result == "CLI_RESULT")
    }

    /// OpenAI (not OAuth-signed-in) with the Codex CLI active routes through the
    /// CLI enhancer with the `.codex` backend.
    @Test func codexCliServerRouteEnhancesViaCliServerEnhancer() async throws {
        let cli = MockCLIServerEnhancer()
        cli.activeProviders = [.codex]
        cli.serverURL = "http://mac.local:4000"
        cli.stubEnhanceResult = "CODEX_RESULT"

        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: MockKeychainService(),
            networkService: MockNetworkService(),
            oauthManager: MockOAuthManager(),
            cliServerEnhancer: cli
        )
        let mode = makeMode(aiProvider: .openAI, aiModel: "gpt-test")

        let (result, _) = try await sut.generateVariation(text: "hi", preset: PresetCatalog.regular, modeOverride: mode)

        #expect(cli.capturedProvider == .codex)
        #expect(result == "CODEX_RESULT")
    }

    /// Gemini (not OAuth-signed-in) with the Gemini CLI active routes through the
    /// CLI enhancer with the `.gemini` backend.
    @Test func geminiCliServerRouteEnhancesViaCliServerEnhancer() async throws {
        let cli = MockCLIServerEnhancer()
        cli.activeProviders = [.gemini]
        cli.serverURL = "http://mac.local:4000"
        cli.stubEnhanceResult = "GEMINI_RESULT"

        let sut = AIService(
            userDefaults: makeDefaults(),
            keychain: MockKeychainService(),
            networkService: MockNetworkService(),
            oauthManager: MockOAuthManager(),
            cliServerEnhancer: cli
        )
        let mode = makeMode(aiProvider: .gemini, aiModel: "gemini-test")

        let (result, _) = try await sut.generateVariation(text: "hi", preset: PresetCatalog.regular, modeOverride: mode)

        #expect(cli.capturedProvider == .gemini)
        #expect(result == "GEMINI_RESULT")
    }

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
