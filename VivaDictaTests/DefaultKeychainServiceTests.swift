//
//  DefaultKeychainServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.06.20
//

import Foundation
import Testing
import Keychain

/// Exercises the real `DefaultKeychainService` against the system keychain.
///
/// These live in the app test target (not the Keychain SPM module) on purpose:
/// the production keychain uses `kSecUseDataProtectionKeychain`, which requires
/// the keychain-access-group entitlement. An unsigned `swift test` host bundle
/// lacks it (every `SecItemAdd` returns `errSecMissingEntitlement`), so the
/// round-trip can only be verified in the simulator, hosted inside the entitled
/// VivaDicta app.
///
/// Each test uses a unique `service` namespace so items never collide across
/// tests or runs, uses `syncable: false` to keep items local, and cleans up.
@Suite("DefaultKeychainService")
struct DefaultKeychainServiceTests {

    private func makeSUT() -> DefaultKeychainService {
        DefaultKeychainService(service: "com.antonnovoselov.VivaDicta.tests.\(UUID().uuidString)")
    }

    @Test func savesAndReadsBackString() {
        let sut = makeSUT()
        defer { sut.delete(forKey: "token", syncable: false) }

        #expect(sut.save("secret-value", forKey: "token", syncable: false))
        #expect(sut.getString(forKey: "token", syncable: false) == "secret-value")
    }

    @Test func savesAndReadsBackData() {
        let sut = makeSUT()
        defer { sut.delete(forKey: "blob", syncable: false) }
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF])

        #expect(sut.save(data: bytes, forKey: "blob", syncable: false))
        #expect(sut.getData(forKey: "blob", syncable: false) == bytes)
    }

    @Test func overwritesExistingValueForSameKey() {
        let sut = makeSUT()
        defer { sut.delete(forKey: "token", syncable: false) }

        #expect(sut.save("first", forKey: "token", syncable: false))
        #expect(sut.save("second", forKey: "token", syncable: false))
        // save() deletes any prior item first, so the latest value wins.
        #expect(sut.getString(forKey: "token", syncable: false) == "second")
    }

    @Test func getStringReturnsNilForMissingKey() {
        let sut = makeSUT()
        #expect(sut.getString(forKey: "absent", syncable: false) == nil)
        #expect(sut.getData(forKey: "absent", syncable: false) == nil)
    }

    @Test func deleteRemovesStoredValue() {
        let sut = makeSUT()
        #expect(sut.save("temp", forKey: "token", syncable: false))

        #expect(sut.delete(forKey: "token", syncable: false))
        #expect(sut.getString(forKey: "token", syncable: false) == nil)
    }

    @Test func deleteOfMissingKeyIsTreatedAsSuccess() {
        let sut = makeSUT()
        // errSecItemNotFound is mapped to success so callers can delete blindly.
        #expect(sut.delete(forKey: "never-saved", syncable: false))
    }
}
