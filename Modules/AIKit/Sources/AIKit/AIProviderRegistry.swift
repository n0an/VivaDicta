// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os
import AICore
import AIProviders
import Keychain
import OAuth
import Networking

/// Builds a configured `any AITextProvider` for a resolved `AIProviderRoute`.
///
/// This is the AI stack's composition point: it owns the per-backend config
/// assembly (Keychain API-key lookup, OAuth token retrieval) and constructs the
/// matching wrapper. Callers depend only on `AITextProvider` once they hold the
/// result. Dependencies mirror `TranscriptionKit` (the orchestrator depends on
/// its impls + the infra they need).
///
/// `@MainActor` because the injected `OAuthManager` / `CopilotOAuthManager` are
/// not `Sendable` (reference types used on the main actor in the app). The async
/// OAuth calls suspend, so this never blocks the main thread.
@MainActor
public struct AIProviderRegistry {
    private let keychain: any KeychainService
    private let oauthManager: any OAuthManager
    private let copilotOAuthManager: any CopilotOAuthManager
    private let networkService: any NetworkService
    private let logger: Logger
    private let baseTimeout: TimeInterval

    public init(
        keychain: any KeychainService,
        oauthManager: any OAuthManager,
        copilotOAuthManager: any CopilotOAuthManager,
        networkService: any NetworkService,
        logger: Logger,
        baseTimeout: TimeInterval = 300
    ) {
        self.keychain = keychain
        self.oauthManager = oauthManager
        self.copilotOAuthManager = copilotOAuthManager
        self.networkService = networkService
        self.logger = logger
        self.baseTimeout = baseTimeout
    }

    /// Builds the configured provider for `route`. Throws `EnhancementError.notConfigured`
    /// when a required API key is missing, or rethrows an OAuth error when a token
    /// cannot be obtained.
    public func makeTextProvider(for route: AIProviderRoute, model: String) async throws -> any AITextProvider {
        // Saved mode selections can outlive a provider's model lineup; map
        // retired ids to their replacements so those modes keep working.
        // Only routes bound to a known provider catalog are normalized -
        // passthrough routes (custom endpoints, Ollama, OpenRouter, ...) send
        // the user-entered id untouched.
        let model = switch route {
        case .anthropic: AIProvider.normalizedModel(model, for: .anthropic)
        case .cloud(let provider): AIProvider.normalizedModel(model, for: provider)
        case .openAIOAuth: AIProvider.normalizedModel(model, for: .openAI)
        case .grokOAuth: AIProvider.normalizedModel(model, for: .grok)
        default: model
        }
        switch route {
        case .appleFoundationModel(let samplingProfile):
            if #available(iOS 26, macOS 26, *) {
                return AppleFMTextProvider(samplingProfile: samplingProfile)
            }
            throw AppleFoundationModelError.notAvailable

        case .anthropic:
            let apiKey = try requireAPIKey(for: .anthropic)
            return AnthropicTextProvider(
                networkService: networkService, logger: logger, baseTimeout: baseTimeout,
                apiKey: apiKey, model: model
            )

        case .cloud(let provider):
            let apiKey = try requireAPIKey(for: provider)
            guard let url = URL(string: provider.baseURL) else { throw EnhancementError.notConfigured }
            // Empty for every provider but OpenCode Zen / Go.
            var headers = OpenCodeHeaders.headers(for: provider)
            headers["Authorization"] = "Bearer \(apiKey)"
            return OpenAICompatibleTextProvider(
                networkService: networkService, logger: logger,
                url: url, modelName: model,
                headers: headers,
                timeout: baseTimeout, errorPrefix: "\(provider.displayName) error"
            )

        case .openAIOAuth:
            let (token, accountId, _) = try await oauthManager.validAccessToken(for: OpenAIOAuthProvider())
            return OpenAIOAuthTextProvider(model: model, accessToken: token, accountId: accountId)

        case .geminiOAuth:
            let (token, _, projectId) = try await oauthManager.validAccessToken(for: GeminiOAuthProvider())
            return GeminiTextProvider(model: model, accessToken: token, projectId: projectId, networkService: networkService)

        case .grokOAuth:
            // The subscription token is a drop-in for the API key: same host,
            // same OpenAI-compatible wire format, `Authorization: Bearer`.
            let (token, _, _) = try await oauthManager.validAccessToken(for: GrokOAuthProvider())
            guard let url = URL(string: AIProvider.grok.baseURL) else { throw EnhancementError.notConfigured }
            return OpenAICompatibleTextProvider(
                networkService: networkService, logger: logger,
                url: url, modelName: model,
                headers: ["Authorization": "Bearer \(token)"],
                timeout: baseTimeout,
                errorPrefix: "\(AIProvider.grok.displayName) error",
                unauthorizedMessage: Self.grokSubscriptionRequiredMessage
            )

        case .copilot:
            let token = try await copilotOAuthManager.validCopilotToken()
            return CopilotTextProvider(model: model, copilotToken: token)

        case .openAICompatibleEndpoint(let url, let headers, let timeout, let errorPrefix, let notFoundMessage, let unauthorizedMessage):
            return OpenAICompatibleTextProvider(
                networkService: networkService, logger: logger,
                url: url, modelName: model, headers: headers, timeout: timeout,
                errorPrefix: errorPrefix, notFoundMessage: notFoundMessage, unauthorizedMessage: unauthorizedMessage
            )
        }
    }

    /// Shown when xAI accepts the subscription token but refuses inference.
    ///
    /// xAI runs its own allowlist on the OAuth API surface, so sign-in can
    /// succeed while `api.x.ai` still answers 403 - reported by standard
    /// SuperGrok and X Premium subscribers alike. A generic "unauthorized"
    /// would read as our bug, so name the actual cause and the way out.
    static let grokSubscriptionRequiredMessage = """
        xAI rejected this request for your Grok subscription. xAI limits which \
        plans can use Grok through a connected app, and a new subscription can \
        take a while to activate. You can add an xAI API key instead, which \
        always works.
        """

    /// Reads the provider's API key from the Keychain, mirroring `AIProvider.apiKey`.
    private func requireAPIKey(for provider: AIProvider) throws -> String {
        let key = provider.keychainKey
        guard !key.isEmpty, let apiKey = keychain.getString(forKey: key), !apiKey.isEmpty else {
            throw EnhancementError.notConfigured
        }
        return apiKey
    }
}
