//
//  CloudModel+APIKey.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation

// This extension lives in a main-target-only file because it transitively
// depends on `AIProvider.apiKey`, which uses the Keychain package that
// extensions do not link against. CloudModel itself is shared with
// extensions; this convenience property is not.
extension CloudModel {
    var apiKey: String? {
        provider.mappedAIProvider?.apiKey
    }
}
