// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os
import AICore
import AIProviders
import OAuth

/// A resolved non-streaming enhancement request - everything `TextEnhancer`
/// needs to run the cloud / CLI / OAuth routing, with the caller's runtime
/// state already decided (`isOAuthSignedIn`, `hasAPIKey`).
public struct EnhancementInput: Sendable {
    public let provider: AIProvider
    public let model: String
    public let systemMessage: String
    public let userMessage: String
    /// Whether `provider` is OAuth-signed-in (the caller resolves which
    /// provider this applies to).
    public let isOAuthSignedIn: Bool
    /// Whether an API key exists for `provider` (used for fallback decisions).
    public let hasAPIKey: Bool

    public init(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        userMessage: String,
        isOAuthSignedIn: Bool,
        hasAPIKey: Bool
    ) {
        self.provider = provider
        self.model = model
        self.systemMessage = systemMessage
        self.userMessage = userMessage
        self.isOAuthSignedIn = isOAuthSignedIn
        self.hasAPIKey = hasAPIKey
    }
}

/// Runs the non-streaming enhancement state machine for a resolved request:
/// the CLI-server / OAuth / cloud routing and the fallback chain
/// (OAuth -> CLI -> API key). Lifted out of `AIService` so the orchestration is
/// a unit-testable value in `AIKit`, depending on the registry + the CLI seam
/// rather than the app's `@Observable` state.
///
/// Does NOT handle Apple Foundation Model or the locally-configured
/// Ollama / Custom endpoints - those stay with the caller (Apple FM reuses a
/// cached service; Ollama/Custom build their request from app config).
@MainActor
public struct TextEnhancer {
    private let registry: AIProviderRegistry
    private let cliServerEnhancer: any CLIServerEnhancer
    private let logger: Logger

    public init(registry: AIProviderRegistry, cliServerEnhancer: any CLIServerEnhancer, logger: Logger) {
        self.registry = registry
        self.cliServerEnhancer = cliServerEnhancer
        self.logger = logger
    }

    public func enhance(_ input: EnhancementInput) async throws -> String {
        // Anthropic CLI Server: route Anthropic requests through the remote server when enabled.
        if input.provider == .anthropic && cliServerEnhancer.isCliActive(for: .anthropic),
           let serverURL = cliServerEnhancer.serverURL, !serverURL.isEmpty {
            logger.logDebug("AI Processing - Using Anthropic CLI Server at \(serverURL)")
            do {
                let result = try await cliServerEnhancer.enhance(
                    text: input.userMessage, systemPrompt: input.systemMessage, model: input.model, provider: .anthropic
                )
                return AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                // Fall back to API key if the server fails and a key exists.
                if input.hasAPIKey {
                    logger.logWarning("Anthropic CLI Server failed, falling back to API key: \(error.localizedDescription)")
                } else {
                    throw EnhancementError.customError(error.localizedDescription)
                }
            }
        }

        // OpenAI OAuth: route OpenAI requests through the OpenAI backend API when signed in.
        if input.provider == .openAI && input.isOAuthSignedIn {
            do {
                let model = input.model.isEmpty ? OpenAIOAuthClient.defaultModel : input.model
                let provider = try await registry.makeTextProvider(for: .openAIOAuth, model: model)
                let result = try await provider.enhance(systemMessage: input.systemMessage, userMessage: input.userMessage)
                return AIEnhancementOutputFilter.filter(result)
            } catch let error as OAuthError {
                // If OAuth fails, fall through to CLI or API key.
                if cliServerEnhancer.isCliActive(for: .codex) || input.hasAPIKey {
                    logger.logWarning("OpenAI OAuth failed, falling back: \(error.localizedDescription)")
                } else {
                    throw EnhancementError.customError(error.errorDescription ?? "OpenAI OAuth error")
                }
            }
        }

        // Gemini OAuth: route Gemini requests through OAuth when signed in.
        if input.provider == .gemini && input.isOAuthSignedIn {
            do {
                let model = input.model.isEmpty ? GeminiAPIClient.defaultModel : input.model
                let provider = try await registry.makeTextProvider(for: .geminiOAuth, model: model)
                let result = try await provider.enhance(systemMessage: input.systemMessage, userMessage: input.userMessage)
                return AIEnhancementOutputFilter.filter(result)
            } catch let error as EnhancementError {
                // Rate limit etc. - don't fall through, surface directly.
                throw error
            } catch let error as OAuthError {
                // If OAuth fails, fall through to CLI or API key.
                if cliServerEnhancer.isCliActive(for: .gemini) || input.hasAPIKey {
                    logger.logWarning("Gemini OAuth failed, falling back: \(error.localizedDescription)")
                } else {
                    throw EnhancementError.customError(error.errorDescription ?? "Gemini OAuth error")
                }
            }
        }

        // Grok OAuth: route xAI requests through the subscription token when
        // signed in. No CLI server for xAI, so an API key is the only fallback.
        if input.provider == .grok && input.isOAuthSignedIn {
            do {
                let provider = try await registry.makeTextProvider(for: .grokOAuth, model: input.model)
                let result = try await provider.enhance(systemMessage: input.systemMessage, userMessage: input.userMessage)
                return AIEnhancementOutputFilter.filter(result)
            } catch let error as EnhancementError {
                // Includes the 403 "subscription not entitled" message, which is
                // actionable on its own - surface it rather than silently
                // spending the user's API credits instead.
                throw error
            } catch let error as OAuthError {
                if input.hasAPIKey {
                    logger.logWarning("Grok OAuth failed, falling back to API key: \(error.localizedDescription)")
                } else {
                    throw EnhancementError.customError(error.errorDescription ?? "Grok OAuth error")
                }
            }
        }

        // Codex CLI via Mac server: route OpenAI requests through the CLI server when enabled.
        if input.provider == .openAI && cliServerEnhancer.isCliActive(for: .codex),
           let serverURL = cliServerEnhancer.serverURL, !serverURL.isEmpty {
            logger.logDebug("AI Processing - Using Codex CLI Server at \(serverURL)")
            do {
                let result = try await cliServerEnhancer.enhance(
                    text: input.userMessage, systemPrompt: input.systemMessage, model: input.model, provider: .codex
                )
                return AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                if input.hasAPIKey {
                    logger.logWarning("Codex CLI Server failed, falling back to API key: \(error.localizedDescription)")
                } else {
                    throw EnhancementError.customError(error.localizedDescription)
                }
            }
        }

        // Gemini CLI via Mac server: route Gemini requests through the CLI server when enabled.
        if input.provider == .gemini && cliServerEnhancer.isCliActive(for: .gemini),
           let serverURL = cliServerEnhancer.serverURL, !serverURL.isEmpty {
            logger.logDebug("AI Processing - Using Gemini CLI Server at \(serverURL)")
            do {
                let result = try await cliServerEnhancer.enhance(
                    text: input.userMessage, systemPrompt: input.systemMessage, model: input.model, provider: .gemini
                )
                return AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                if input.hasAPIKey {
                    logger.logWarning("Gemini CLI Server failed, falling back to API key: \(error.localizedDescription)")
                } else {
                    throw EnhancementError.customError(error.localizedDescription)
                }
            }
        }

        // GitHub Copilot: route through the Copilot API when signed in.
        if input.provider == .copilot && input.isOAuthSignedIn {
            do {
                let model = input.model.isEmpty ? CopilotAPIClient.defaultModel : input.model
                let provider = try await registry.makeTextProvider(for: .copilot, model: model)
                let result = try await provider.enhance(systemMessage: input.systemMessage, userMessage: input.userMessage)
                return AIEnhancementOutputFilter.filter(result)
            } catch let error as EnhancementError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }
        }

        // Cloud providers. Anthropic uses its own Messages API; every other cloud
        // provider is OpenAI-compatible. The registry is the single source of the
        // API-key precondition (throws `.notConfigured` when the key is missing).
        logger.logDebug("AI Processing - System Message: \(input.systemMessage)")
        logger.logDebug("AI Processing - User Message: \(input.userMessage)")

        let route: AIProviderRoute = input.provider == .anthropic ? .anthropic : .cloud(input.provider)
        let provider = try await registry.makeTextProvider(for: route, model: input.model)
        return try await provider.enhance(systemMessage: input.systemMessage, userMessage: input.userMessage)
    }
}
