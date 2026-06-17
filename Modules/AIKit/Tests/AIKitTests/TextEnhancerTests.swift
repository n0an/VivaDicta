// Copyright © 2026 Anton Novoselov. All rights reserved.

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

/// Test double for the CLI-server seam.
@MainActor
private final class MockCLIServerEnhancer: CLIServerEnhancer {
    var activeProviders: Set<CLIServerProvider> = []
    var serverURL: String?
    var stubResult = ""
    var stubError: Error?
    private(set) var enhanceCallCount = 0
    private(set) var capturedProvider: CLIServerProvider?

    func isCliActive(for provider: CLIServerProvider) -> Bool { activeProviders.contains(provider) }

    func enhance(text: String, systemPrompt: String, model: String, provider: CLIServerProvider) async throws -> String {
        enhanceCallCount += 1
        capturedProvider = provider
        if let stubError { throw stubError }
        return stubResult
    }
}

/// Unit tests for the non-streaming orchestration now that it lives in AIKit
/// rather than `AIService` - the cloud-default route, the CLI routes, and the
/// CLI->API-key fallback decisions, driven through mocked infra.
@MainActor
@Suite("TextEnhancer", .tags(.networking))
struct TextEnhancerTests {

    private struct CLIError: Error {}

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeSUT(
        keychain: MockKeychainService = MockKeychainService(),
        net: MockNetworkService = MockNetworkService(),
        cli: MockCLIServerEnhancer = MockCLIServerEnhancer(),
        oauth: MockOAuthManager = MockOAuthManager()
    ) -> TextEnhancer {
        let registry = AIProviderRegistry(
            keychain: keychain,
            oauthManager: oauth,
            copilotOAuthManager: MockCopilotOAuthManager(),
            networkService: net,
            logger: Logger(subsystem: "test", category: "TextEnhancerTests"),
            baseTimeout: 30
        )
        return TextEnhancer(registry: registry, cliServerEnhancer: cli, logger: Logger(subsystem: "test", category: "TextEnhancerTests"))
    }

    private func input(provider: AIProvider, isOAuthSignedIn: Bool = false, hasAPIKey: Bool = true) -> EnhancementInput {
        EnhancementInput(provider: provider, model: "m", systemMessage: "S", userMessage: "U", isOAuthSignedIn: isOAuthSignedIn, hasAPIKey: hasAPIKey)
    }

    @Test func cloudDefaultRouteEnhancesViaRegistry() async throws {
        let keychain = MockKeychainService()
        _ = keychain.save("ANTHROPIC_KEY", forKey: "anthropicAPIKey")
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"content":[{"text":"OK"}]}"#.utf8), http(200)))
        let sut = makeSUT(keychain: keychain, net: net)

        let result = try await sut.enhance(input(provider: .anthropic))

        #expect(result == "OK")
        #expect(net.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    }

    @Test func anthropicCliActiveRoutesThroughCliServer() async throws {
        let cli = MockCLIServerEnhancer()
        cli.activeProviders = [.anthropic]
        cli.serverURL = "http://mac:4000"
        cli.stubResult = "CLI_RESULT"
        let sut = makeSUT(cli: cli)

        let result = try await sut.enhance(input(provider: .anthropic, hasAPIKey: false))

        #expect(cli.enhanceCallCount == 1)
        #expect(cli.capturedProvider == .anthropic)
        #expect(result == "CLI_RESULT")
    }

    @Test func cliFailureWithoutKeyThrows() async {
        let cli = MockCLIServerEnhancer()
        cli.activeProviders = [.anthropic]
        cli.serverURL = "http://mac:4000"
        cli.stubError = CLIError()
        let sut = makeSUT(cli: cli)

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.enhance(input(provider: .anthropic, hasAPIKey: false))
        }
    }

    @Test func cliFailureWithKeyFallsThroughToCloud() async throws {
        let keychain = MockKeychainService()
        _ = keychain.save("ANTHROPIC_KEY", forKey: "anthropicAPIKey")
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"content":[{"text":"CLOUD_OK"}]}"#.utf8), http(200)))
        let cli = MockCLIServerEnhancer()
        cli.activeProviders = [.anthropic]
        cli.serverURL = "http://mac:4000"
        cli.stubError = CLIError()
        let sut = makeSUT(keychain: keychain, net: net, cli: cli)

        let result = try await sut.enhance(input(provider: .anthropic, hasAPIKey: true))

        #expect(cli.enhanceCallCount == 1)            // CLI was attempted
        #expect(result == "CLOUD_OK")                 // then fell through to the cloud route
        #expect(net.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    }

    // MARK: - OAuth branches (the subtle rethrow / fallthrough behavior)

    /// Gemini OAuth throwing an `EnhancementError` (e.g. a 429 rate limit) must
    /// surface directly - the `catch EnhancementError` precedes `catch OAuthError`,
    /// so it does NOT fall through to the cloud route.
    @Test func geminiOAuthEnhancementErrorSurfacesDirectlyWithoutFallthrough() async {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .success((token: "GEM_TOK", accountId: nil, projectId: nil))
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data("rate limited".utf8), http(429))) // Gemini maps 429 -> EnhancementError
        let sut = makeSUT(net: net, oauth: oauth)

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.enhance(input(provider: .gemini, isOAuthSignedIn: true, hasAPIKey: true))
        }
        // Only the Gemini OAuth (cloudcode) request was made - no cloud fallthrough.
        #expect(net.capturedRequest?.url?.absoluteString.contains("cloudcode-pa.googleapis.com") == true)
    }

    /// OAuth token failure (an `OAuthError`) falls through to the cloud route when
    /// an API key exists.
    @Test func geminiOAuthFailureFallsThroughToCloudWhenKeyExists() async throws {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .failure(OAuthError.noCredential)
        let keychain = MockKeychainService()
        _ = keychain.save("GEMINI_KEY", forKey: "geminiAPIKey")
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"choices":[{"message":{"content":"CLOUD_OK"}}]}"#.utf8), http(200)))
        let sut = makeSUT(keychain: keychain, net: net, oauth: oauth)

        let result = try await sut.enhance(input(provider: .gemini, isOAuthSignedIn: true, hasAPIKey: true))

        #expect(result == "CLOUD_OK")
        // Fell through to the cloud (OpenAI-compatible) Gemini endpoint with the Bearer key.
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer GEMINI_KEY")
    }

    /// OAuth token failure with no API key and no active CLI surfaces as
    /// `EnhancementError.customError` (no silent fall-through).
    @Test func openAIOAuthFailureWithoutKeyOrCliThrowsCustomError() async {
        let oauth = MockOAuthManager()
        oauth.stubValidAccessTokenResponse = .failure(OAuthError.noCredential)
        let sut = makeSUT(oauth: oauth) // no CLI active, no key

        await #expect(throws: EnhancementError.self) {
            _ = try await sut.enhance(input(provider: .openAI, isOAuthSignedIn: true, hasAPIKey: false))
        }
    }
}
