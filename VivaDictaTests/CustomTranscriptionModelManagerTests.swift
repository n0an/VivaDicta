//
//  CustomTranscriptionModelManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing
import KeychainMocks
@testable import VivaDicta

/// Sut + mock pattern: sut is the real `CustomTranscriptionModelManager`,
/// `MockKeychainService` is the injected dependency. Only the keychain-
/// backed API-key paths are tested here; full saveConfiguration() requires
/// a valid endpoint + model name to pass validation and is covered by its
/// own configuration tests elsewhere.
@MainActor
struct CustomTranscriptionModelManagerTests {

    /// Mirrors the private constants in CustomTranscriptionModelManager.
    /// Kept in sync manually so a production-side rename surfaces here.
    private static let keychainKey = "customTranscriptionAPIKey"
    private static let fixedModelId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let mockKeychain: MockKeychainService
    let sut: CustomTranscriptionModelManager

    init() {
        let mock = MockKeychainService()
        self.mockKeychain = mock
        self.sut = CustomTranscriptionModelManager(keychain: mock)
    }

    @Test func apiKeyReturnsNilWhenKeychainEmpty() {
        #expect(sut.apiKey == nil)
    }

    @Test func apiKeyReturnsValueFromKeychain() {
        mockKeychain.save("secret-key", forKey: Self.keychainKey, syncable: true)

        #expect(sut.apiKey == "secret-key")
    }

    @Test func clearConfigurationDeletesAPIKey() {
        mockKeychain.save("secret-key", forKey: Self.keychainKey, syncable: true)
        #expect(sut.apiKey == "secret-key")

        sut.clearConfiguration()

        #expect(mockKeychain.getString(forKey: Self.keychainKey, syncable: true) == nil,
                "clearConfiguration must remove the API key from the keychain")
    }

    @Test func getAPIKeyForFixedModelIdReadsKeychain() {
        mockKeychain.save("secret-key", forKey: Self.keychainKey, syncable: true)

        #expect(sut.getAPIKey(forModelId: Self.fixedModelId) == "secret-key")
    }

    @Test func getAPIKeyForUnknownModelIdReturnsNil() {
        mockKeychain.save("secret-key", forKey: Self.keychainKey, syncable: true)
        let strangerId = UUID()

        #expect(sut.getAPIKey(forModelId: strangerId) == nil,
                "getAPIKey must reject any model ID other than the fixed singleton ID")
    }
}
