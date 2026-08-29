//
//  CloudModel+APIKey.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import AICore
import OAuth

// This extension lives in a main-target-only file because it transitively
// depends on `AIProvider.apiKey`, which uses the Keychain package that
// extensions do not link against. CloudModel itself is shared with
// extensions; this convenience property is not.
extension CloudModel {
    var apiKey: String? {
        provider.mappedAIProvider?.apiKey
    }

    /// True when the model has a credential to transcribe with: its provider's
    /// API key, or a signed-in Grok subscription for the providers that take
    /// one (xAI). Views read this rather than `apiKey != nil` so a
    /// subscription-only setup doesn't look unconfigured.
    @MainActor
    var isConfigured: Bool {
        apiKey != nil || hasGrokSubscription
    }

    /// A signed-in SuperGrok / X Premium subscription this model can use in
    /// place of an API key.
    @MainActor
    var hasGrokSubscription: Bool {
        provider.acceptsGrokSubscription && DefaultOAuthManager.shared.isSignedIn(provider: GrokOAuthProvider())
    }
}
