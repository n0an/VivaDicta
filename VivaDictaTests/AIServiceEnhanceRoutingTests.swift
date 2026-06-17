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
@testable import VivaDicta

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
        net.stubSendResponse = .success((Data(#"{"content":[{"text":"OK"}]}"#.utf8), http(200)))

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

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}
