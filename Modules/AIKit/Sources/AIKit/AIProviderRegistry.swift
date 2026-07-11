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
        let model = AIProvider.normalizedModel(model)
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
            return OpenAICompatibleTextProvider(
                networkService: networkService, logger: logger,
                url: url, modelName: model,
                headers: ["Authorization": "Bearer \(apiKey)"],
                timeout: baseTimeout, errorPrefix: "\(provider.displayName) error"
            )

        case .openAIOAuth:
            let (token, accountId, _) = try await oauthManager.validAccessToken(for: OpenAIOAuthProvider())
            return OpenAIOAuthTextProvider(model: model, accessToken: token, accountId: accountId)

        case .geminiOAuth:
            let (token, _, projectId) = try await oauthManager.validAccessToken(for: GeminiOAuthProvider())
            return GeminiTextProvider(model: model, accessToken: token, projectId: projectId, networkService: networkService)

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

    /// Reads the provider's API key from the Keychain, mirroring `AIProvider.apiKey`.
    private func requireAPIKey(for provider: AIProvider) throws -> String {
        let key = provider.keychainKey
        guard !key.isEmpty, let apiKey = keychain.getString(forKey: key), !apiKey.isEmpty else {
            throw EnhancementError.notConfigured
        }
        return apiKey
    }
}
