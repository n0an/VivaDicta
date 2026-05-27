//
//  APIKeyMigrationServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.27
//

import Foundation
import Keychain
import KeychainMocks
import Testing
@testable import VivaDicta

struct APIKeyMigrationServiceTests {

    private let suiteName = "APIKeyMigrationTests.\(UUID().uuidString)"
    private let flagSuiteName = "APIKeyMigrationTests.flag.\(UUID().uuidString)"

    private func makeDefaults() -> (source: UserDefaults, flag: UserDefaults) {
        let source = UserDefaults(suiteName: suiteName)!
        source.removePersistentDomain(forName: suiteName)
        let flag = UserDefaults(suiteName: flagSuiteName)!
        flag.removePersistentDomain(forName: flagSuiteName)
        return (source, flag)
    }

    private func makeSUT(
        keychain: MockKeychainService,
        sourceDefaults: UserDefaults,
        flagDefaults: UserDefaults
    ) -> APIKeyMigrationService {
        APIKeyMigrationService(
            keychain: keychain,
            sourceDefaults: sourceDefaults,
            flagDefaults: flagDefaults
        )
    }

    // MARK: - Flag short-circuit

    @Test func migrateIfNeeded_isNoOp_whenAlreadyMigrated() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()
        source.set("sk-test", forKey: "apiKeyTemplate" + AIProvider.openAI.rawValue)
        flag.set(true, forKey: "HasMigratedAPIKeysToKeychain")

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(keychain.saveStringCallCount == 0)
    }

    // MARK: - Provider key migration

    @Test func migrateIfNeeded_movesProviderKey_fromSourceDefaultsToKeychain() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()
        source.set("sk-openai-xyz", forKey: "apiKeyTemplate" + AIProvider.openAI.rawValue)

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(keychain.getString(forKey: AIProvider.openAI.keychainKey) == "sk-openai-xyz")
    }

    @Test func migrateIfNeeded_migratesMultipleProviders_inOnePass() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()
        source.set("k-openai", forKey: "apiKeyTemplate" + AIProvider.openAI.rawValue)
        source.set("k-anthropic", forKey: "apiKeyTemplate" + AIProvider.anthropic.rawValue)
        source.set("k-groq", forKey: "apiKeyTemplate" + AIProvider.groq.rawValue)

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(keychain.getString(forKey: AIProvider.openAI.keychainKey) == "k-openai")
        #expect(keychain.getString(forKey: AIProvider.anthropic.keychainKey) == "k-anthropic")
        #expect(keychain.getString(forKey: AIProvider.groq.keychainKey) == "k-groq")
    }

    @Test func migrateIfNeeded_skipsEmptyAndMissingKeys() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()
        source.set("", forKey: "apiKeyTemplate" + AIProvider.openAI.rawValue)
        // anthropic key not set at all

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(keychain.saveStringCallCount == 0)
    }

    // MARK: - Custom transcription key migration

    @Test func migrateIfNeeded_migratesCustomTranscriptionKey() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()
        source.set("custom-transcribe-key", forKey: "apiKey.customTranscription")

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(keychain.getString(forKey: "customTranscriptionAPIKey") == "custom-transcribe-key")
    }

    // MARK: - Completion flag

    @Test func migrateIfNeeded_setsCompletionFlag_afterRun() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(flag.bool(forKey: "HasMigratedAPIKeysToKeychain"))
    }

    @Test func migrateIfNeeded_setsFlag_evenWhenNoKeysToMigrate() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()

        #expect(flag.bool(forKey: "HasMigratedAPIKeysToKeychain"))
        #expect(keychain.saveStringCallCount == 0)
    }

    // MARK: - Idempotency

    @Test func migrateIfNeeded_secondCall_isNoOp() {
        let (source, flag) = makeDefaults()
        let keychain = MockKeychainService()
        source.set("k-openai", forKey: "apiKeyTemplate" + AIProvider.openAI.rawValue)

        let sut = makeSUT(keychain: keychain, sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded()
        let countAfterFirst = keychain.saveStringCallCount

        sut.migrateIfNeeded()

        #expect(keychain.saveStringCallCount == countAfterFirst)
    }
}
