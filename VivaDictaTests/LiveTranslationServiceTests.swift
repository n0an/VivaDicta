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

    let mockKeychain: MockKeychainService
    let sut: LiveTranslationService

    init() {
        mockKeychain = MockKeychainService()
        sut = LiveTranslationService(keychain: mockKeychain)
    }

    @Test func hasAPIKey_returnsFalse_whenKeychainIsEmpty() {
        #expect(sut.hasAPIKey == false)
    }

    @Test func hasAPIKey_returnsTrue_whenSonioxAPIKeyIsStored() {
        mockKeychain.save("test-api-key", forKey: "sonioxAPIKey", syncable: true)

        #expect(sut.hasAPIKey == true)
    }

    @Test func hasAPIKey_returnsFalse_whenStoredValueIsWhitespaceOnly() {
        mockKeychain.save("   ", forKey: "sonioxAPIKey", syncable: true)

        #expect(sut.hasAPIKey == false)
    }
}
