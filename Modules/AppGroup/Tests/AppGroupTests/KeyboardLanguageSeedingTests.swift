//
//  KeyboardLanguageSeedingTests.swift
//  AppGroupTests
//
//  Created by Anton Novoselov on 2026.09.06
//

import Foundation
import Testing
@testable import AppGroup

/// Covers `AppGroupCoordinator.ensureNewLanguagesSeeded` - the path that
/// auto-enables a language added after the one-shot onboarding migration has
/// already run.
struct KeyboardLanguageSeedingTests {

    private let suiteName = "KeyboardLanguageSeedingTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let sut: AppGroupCoordinator

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        sut = AppGroupCoordinator(userDefaults: defaults)
    }

    /// Puts the suite in the state of an install that migrated under a build
    /// predating `kSeededLanguages`: migration marker set, no seeded record.
    private func simulateAlreadyMigrated(enabled: Set<KeyboardLanguage>) {
        defaults.set(true, forKey: "didMigrateLanguageSettings_v1")
        defaults.set(
            AppGroupCoordinator.serializeLanguages(enabled),
            forKey: AppGroupCoordinator.kEnabledKeyboardLanguages
        )
        defaults.removeObject(forKey: "seededKeyboardLanguages")
    }

    private var storedEnabled: Set<KeyboardLanguage> {
        AppGroupCoordinator.parseLanguages(
            defaults.string(forKey: AppGroupCoordinator.kEnabledKeyboardLanguages)
        )
    }

    // MARK: - The bug this fixes

    @Test func newLanguageIsEnabledForAnAlreadyMigratedInstall() {
        simulateAlreadyMigrated(enabled: [.english])

        sut.ensureNewLanguagesSeeded(systemPreferred: [.english, .czech])

        #expect(storedEnabled == [.english, .czech])
    }

    @Test func newLanguageIsSkippedWhenItDoesNotMatchSystemLanguages() {
        simulateAlreadyMigrated(enabled: [.english])

        sut.ensureNewLanguagesSeeded(systemPreferred: [.english, .german])

        #expect(storedEnabled == [.english])
    }

    // MARK: - Never override an explicit user choice

    @Test func aLanguageAlreadyOfferedIsNotReEnabled() {
        // The user was offered Russian, then deliberately switched it off.
        defaults.set(true, forKey: "didMigrateLanguageSettings_v1")
        defaults.set(
            AppGroupCoordinator.serializeLanguages([.english]),
            forKey: AppGroupCoordinator.kEnabledKeyboardLanguages
        )
        defaults.set(
            AppGroupCoordinator.serializeLanguages(Set(KeyboardLanguage.allCases)),
            forKey: "seededKeyboardLanguages"
        )

        sut.ensureNewLanguagesSeeded(systemPreferred: [.english, .russian])

        #expect(storedEnabled == [.english])
    }

    @Test func eachLanguageIsConsideredOnlyOnce() {
        simulateAlreadyMigrated(enabled: [.english])

        // First pass: Czech is not among the user's system languages.
        sut.ensureNewLanguagesSeeded(systemPreferred: [.english])
        #expect(storedEnabled == [.english])

        // Later the user adds Czech in iOS Settings. Czech has already been
        // offered, so we do not reconsider it.
        sut.ensureNewLanguagesSeeded(systemPreferred: [.english, .czech])
        #expect(storedEnabled == [.english])
    }

    @Test func seedingIsAdditiveAndKeepsExistingSelections() {
        simulateAlreadyMigrated(enabled: [.english, .french, .russian])

        sut.ensureNewLanguagesSeeded(systemPreferred: [.czech])

        #expect(storedEnabled == [.english, .french, .russian, .czech])
    }

    // MARK: - Bookkeeping

    @Test func seedingRecordsEveryLanguageAsOffered() {
        simulateAlreadyMigrated(enabled: [.english])

        sut.ensureNewLanguagesSeeded(systemPreferred: [.czech])

        let seeded = AppGroupCoordinator.parseLanguages(
            defaults.string(forKey: "seededKeyboardLanguages")
        )
        #expect(seeded == Set(KeyboardLanguage.allCases))
    }

    @Test func theOneShotMigrationMarksEverythingAsOffered() {
        // A fresh install: the migration seeds from the system list itself, so
        // seeding must find nothing left to do.
        _ = sut.enabledKeyboardLanguages

        let seeded = AppGroupCoordinator.parseLanguages(
            defaults.string(forKey: "seededKeyboardLanguages")
        )
        #expect(seeded == Set(KeyboardLanguage.allCases))
    }

    // MARK: - Serialization helpers

    @Test func serializationUsesCanonicalOrderRegardlessOfSetOrder() {
        let raw = AppGroupCoordinator.serializeLanguages([.russian, .english, .czech])

        #expect(raw == "english,czech,russian")
    }

    @Test func parsingDropsUnknownRawValues() {
        let parsed = AppGroupCoordinator.parseLanguages("english,klingon,czech")

        #expect(parsed == [.english, .czech])
    }

    @Test func parsingEmptyOrMissingYieldsNoLanguages() {
        #expect(AppGroupCoordinator.parseLanguages(nil).isEmpty)
        #expect(AppGroupCoordinator.parseLanguages("").isEmpty)
    }

    // MARK: - System language matching

    @Test func systemMatchingIgnoresRegionSubtags() {
        let matched = KeyboardLanguage.preferredFromSystem(
            preferredLanguages: ["cs-CZ", "en-GB"]
        )

        #expect(matched == [.czech, .english])
    }

    @Test func systemMatchingIgnoresUnsupportedLanguages() {
        let matched = KeyboardLanguage.preferredFromSystem(
            preferredLanguages: ["ja-JP", "cs-CZ"]
        )

        #expect(matched == [.czech])
    }
}
