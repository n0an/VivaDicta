//
//  LiveTranslationServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import KeychainMocks
import Testing
@testable import VivaDicta

/// First app-target test class using ``MockKeychainService`` (from the
/// `KeychainMocks` module library). Verifies that ``LiveTranslationService``'s
/// `hasAPIKey` property correctly reads from an injected keychain.
@MainActor
struct LiveTranslationServiceTests {

    @Test func hasAPIKey_returnsFalse_whenKeychainIsEmpty() {
        let mockKeychain = MockKeychainService()
        let sut = LiveTranslationService(keychain: mockKeychain)

        #expect(sut.hasAPIKey == false)
    }

    @Test func hasAPIKey_returnsTrue_whenSonioxAPIKeyIsStored() {
        let mockKeychain = MockKeychainService()
        mockKeychain.save("test-api-key", forKey: "sonioxAPIKey", syncable: true)

        let sut = LiveTranslationService(keychain: mockKeychain)

        #expect(sut.hasAPIKey == true)
    }

    @Test func hasAPIKey_returnsFalse_whenStoredValueIsWhitespaceOnly() {
        let mockKeychain = MockKeychainService()
        mockKeychain.save("   ", forKey: "sonioxAPIKey", syncable: true)

        let sut = LiveTranslationService(keychain: mockKeychain)

        #expect(sut.hasAPIKey == false)
    }
}
