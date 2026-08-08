// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AICore
import AIProviders

/// A resolved enhancement route - the decision of *which* backend to use,
/// already made by the caller (it depends on runtime state: OAuth sign-in,
/// CLI-server availability, streaming support). `AIProviderRegistry` turns a
/// route + model into a configured `any AITextProvider`.
///
/// Routes that are not `AITextProvider`s (e.g. a CLI-server fallback) are not
/// represented here - the caller handles those separately.
public enum AIProviderRoute: Sendable {
    /// On-device Apple Foundation Model with the given sampling profile.
    case appleFoundationModel(samplingProfile: AppleFoundationModelSamplingProfile)

    /// Anthropic Messages API, keyed from the Keychain.
    case anthropic

    /// An OpenAI-compatible cloud provider keyed from the Keychain. The
    /// associated provider supplies the base URL and Keychain key.
    case cloud(AIProvider)

    /// OpenAI via OAuth (ChatGPT sign-in).
    case openAIOAuth

    /// Gemini via OAuth (Google sign-in).
    case geminiOAuth

    /// xAI Grok via OAuth (SuperGrok / X Premium subscription sign-in). Hits the
    /// same OpenAI-compatible `api.x.ai` endpoint as `.cloud(.grok)`; only the
    /// bearer differs - a subscription access token instead of an API key.
    case grokOAuth

    /// GitHub Copilot via its device-code OAuth.
    case copilot

    /// A locally-configured OpenAI-compatible endpoint (Ollama / Custom),
    /// whose URL and headers are supplied by the caller (from UserDefaults).
    /// `timeout` is explicit because these self-hosted endpoints use a longer
    /// request timeout than the hosted cloud providers (slow local inference) -
    /// the caller carries it so the registry doesn't silently substitute its
    /// cloud `baseTimeout`.
    case openAICompatibleEndpoint(
        url: URL,
        headers: [String: String],
        timeout: TimeInterval,
        errorPrefix: String,
        notFoundMessage: String? = nil,
        unauthorizedMessage: String? = nil
    )
}
