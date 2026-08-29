//
//  TranscriptionModelProvider+Discovery.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import AICore
import OAuth

// Main-target-only extension because it transitively depends on
// `AIProvider.apiKey`, which uses the Keychain package that extensions
// do not link against. Callers like AIService are main-target-only too.
extension TranscriptionModelProvider {

    /// Discovers the first cloud transcription provider the user can already
    /// transcribe with - an API key in the keychain, or a signed-in Grok
    /// subscription for the providers that accept one. API keys are validated
    /// when saved, so no network call is needed here.
    @MainActor
    static func discoverCloudProvider() -> (provider: TranscriptionModelProvider, modelName: String)? {
        let isGrokSignedIn = DefaultOAuthManager.shared.isSignedIn(provider: GrokOAuthProvider())
        for provider in cloudProviders {
            guard let aiProvider = provider.mappedAIProvider,
                  let modelName = provider.defaultCloudTranscriptionModel else { continue }
            guard aiProvider.apiKey != nil || (provider.acceptsGrokSubscription && isGrokSignedIn) else { continue }
            return (provider, modelName)
        }
        return nil
    }
}
