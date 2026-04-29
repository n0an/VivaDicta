//
//  APIKeyMigrationService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.19
//

import Foundation
import os

/// One-time migration of API keys from UserDefaults (App Group) to Keychain (iCloud sync).
final class APIKeyMigrationService: Sendable {
    static let shared = APIKeyMigrationService()

    private let logger = Logger(category: .keychainService)
    private let migrationCompletedKey = "HasMigratedAPIKeysToKeychain"

    private init() {}

    /// Migrates existing API keys from UserDefaults to Keychain.
    /// Safe to call multiple times — only runs once.
    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else { return }

        logger.logInfo("Starting API key migration from UserDefaults to Keychain")
        var migrated = 0

        // Migrate AIProvider keys
        let providersToMigrate: [AIProvider] = [
            .cerebras, .groq, .gemini, .anthropic, .openAI,
            .openRouter, .grok, .elevenLabs, .deepgram,
            .mistral, .soniox, .gladia, .vercelAIGateway, .huggingFace,
            .customOpenAI
        ]

        for provider in providersToMigrate {
            let oldKey = "apiKeyTemplate" + provider.rawValue
            if let value = UserDefaultsStorage.shared.string(forKey: oldKey),
               !value.isEmpty {
                KeychainService.shared.save(value, forKey: provider.keychainKey)
                migrated += 1
                logger.logInfo("Migrated API key for \(provider.rawValue)")
            }
        }

        // Migrate custom transcription API key
        let oldCustomTranscriptionKey = "apiKey.customTranscription"
        if let value = UserDefaultsStorage.shared.string(forKey: oldCustomTranscriptionKey),
           !value.isEmpty {
            KeychainService.shared.save(value, forKey: "customTranscriptionAPIKey")
            migrated += 1
            logger.logInfo("Migrated custom transcription API key")
        }

        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        logger.logInfo("API key migration completed: \(migrated) keys migrated")
    }
}
