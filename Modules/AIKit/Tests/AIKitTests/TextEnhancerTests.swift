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
        cli: MockCLIServerEnhancer = MockCLIServerEnhancer()
    ) -> TextEnhancer {
        let registry = AIProviderRegistry(
            keychain: keychain,
            oauthManager: MockOAuthManager(),
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
}
