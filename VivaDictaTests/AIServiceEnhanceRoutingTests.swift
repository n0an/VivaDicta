// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import OAuth
import OAuthMocks
import Presets
import Testing
import AICore
@testable import VivaDicta

/// Characterization tests for `AIService`'s non-streaming enhancement routing.
///
/// They pin the outgoing request for the routes that are fully mockable through
/// `AIService`'s injected `OAuthManager` + `NetworkService`, so the Phase 11
/// move to `AIProviderRegistry` is provably behavior-preserving: the same
/// request must still reach the same endpoint carrying the same credential.
///
/// (The Keychain-keyed cloud routes are not characterized here because
/// `AIProvider.apiKey` reads a file-private `DefaultKeychainService`, not the
/// injected one - so they can't be driven without touching the real Keychain.
/// Those routes are covered by `AIProviderRegistry`'s own tests.)
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
}
