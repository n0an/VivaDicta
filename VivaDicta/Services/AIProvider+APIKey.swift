//
//  AIProvider+APIKey.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Keychain
import AICore

// File-private keychain instance so the extension can read API keys
// without forcing every consumer of `AIProvider.apiKey` to inject one.
// `AIProvider` is a domain enum used in non-DI contexts (data models,
// view models) that don't have a ready `AppDependencies` reference.
private let keychain: any KeychainService = DefaultKeychainService()

extension AIProvider {
    /// Reads this provider's API key from the Keychain.
    var apiKey: String? {
        let key = keychainKey
        guard !key.isEmpty else { return nil }
        return keychain.getString(forKey: key)
    }
}
