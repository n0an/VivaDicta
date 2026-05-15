//
//  APIKeyMigrationServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing
import Keychain
import KeychainMocks
@testable import VivaDicta

/// Sut + mock pattern: `sut` is the real `APIKeyMigrationService`,
/// `MockKeychainService` is the injected dependency. Swift Testing creates
/// a fresh suite instance per `@Test`, so each test gets clean state via
/// `init` without needing `setUp`/`tearDown`.
struct APIKeyMigrationServiceTests {

    private static let completionFlagKey = "HasMigratedAPIKeysToKeychain"

    let mockKeychain: MockKeychainService
    let sut: APIKeyMigrationService

    init() {
        // The production class writes its completion flag to
        // UserDefaults.standard; reset it so each test runs from scratch.
        UserDefaults.standard.removeObject(forKey: Self.completionFlagKey)
        let mock = MockKeychainService()
        self.mockKeychain = mock
        self.sut = APIKeyMigrationService(keychain: mock)
    }

    @Test func skipsWhenAlreadyMigrated() {
        UserDefaults.standard.set(true, forKey: Self.completionFlagKey)

        sut.migrateIfNeeded()

        #expect(mockKeychain.saveStringCallCount == 0,
                "No keychain writes should happen once the migration flag is set")
    }

    @Test func setsCompletionFlagAfterRunning() {
        sut.migrateIfNeeded()

        #expect(UserDefaults.standard.bool(forKey: Self.completionFlagKey),
                "Completion flag must be persisted after a run")
    }

    @Test func isIdempotent() {
        sut.migrateIfNeeded()
        let firstRunSaveCount = mockKeychain.saveStringCallCount

        sut.migrateIfNeeded()

        #expect(mockKeychain.saveStringCallCount == firstRunSaveCount,
                "Second run must short-circuit on the flag set by the first")
    }
}
