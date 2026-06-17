//
//  TranscriptionModelProvider+Discovery.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import AICore

// Main-target-only extension because it transitively depends on
// `AIProvider.apiKey`, which uses the Keychain package that extensions
// do not link against. Callers like AIService are main-target-only too.
extension TranscriptionModelProvider {

    /// Discovers the first cloud transcription provider that has an API key in the keychain.
    /// API keys are validated when saved, so no network call is needed here.
    static func discoverCloudProvider() -> (provider: TranscriptionModelProvider, modelName: String)? {
        for provider in cloudProviders {
            guard let aiProvider = provider.mappedAIProvider,
                  let modelName = provider.defaultCloudTranscriptionModel,
                  aiProvider.apiKey != nil else { continue }
            return (provider, modelName)
        }
        return nil
    }
}
