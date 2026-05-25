//
//  PresetManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
import TestUtilities
@testable import Presets

struct PresetManagerTests {

    var sut: PresetManager

    init() {
        let suiteName = "PresetManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: "testPresets")
        defaults.removeObject(forKey: "testHiddenPresetIDs")
        self.sut = PresetManager(
            userDefaults: defaults,
            storageKey: "testPresets",
            hiddenPresetIDsStorageKey: "testHiddenPresetIDs"
        )
    }

    private func makeCustomPreset(
        id: String = "custom_\(UUID().uuidString)",
        name: String = "Custom Test",
        category: String = "Other"
    ) -> Preset {
        Preset(
            id: id,
            name: name,
            icon: "🧪",
            presetDescription: "Test preset",
            category: category,
            promptInstructions: "Test instructions",
            useSystemTemplate: true,
            isBuiltIn: false
        )
    }

    // MARK: - Initialization Tests

    @Test func init_populatesBuiltInPresets() {
        #expect(!sut.presets.isEmpty)
        #expect(sut.presets.contains { $0.id == "regular" })
        #expect(sut.presets.contains { $0.id == "summary" })
        #expect(sut.presets.contains { $0.id == "assistant" })
    }

    @Test func init_builtInPresetsCount_matchesCatalog() {
        let builtInCount = sut.presets.filter(\.isBuiltIn).count

        #expect(builtInCount == PresetCatalog.allBuiltIn.count)
    }

    // MARK: - Lookup Tests

    @Test func preset_forId_returnsCorrectPreset() {
        let preset = sut.preset(for: "regular")

        #expect(preset?.name == "Regular")
        #expect(preset?.isBuiltIn == true)
    }

    @Test func preset_forId_returnsNilForUnknownId() {
        #expect(sut.preset(for: "nonexistent") == nil)
    }

    @Test func presetsInCategory_returnsFilteredPresets() {
        let rewritePresets = sut.presets(in: "Rewrite")

        #expect(!rewritePresets.isEmpty)
        #expect(rewritePresets.allSatisfy { $0.category == "Rewrite" })
    }

    @Test func categories_returnsOrderedCategories() {
        let categories = sut.categories

        #expect(!categories.isEmpty)
        // Rewrite should come before Translate based on categoryOrder
        if let rewriteIdx = categories.firstIndex(of: "Rewrite"),
           let translateIdx = categories.firstIndex(of: "Translate") {
            #expect(rewriteIdx < translateIdx)
        }
    }

    // MARK: - Add Preset Tests

    @Test mutating func addPreset_addsCustomPreset() {
        let initialCount = sut.presets.count
        let preset = makeCustomPreset()

        sut.addPreset(preset)

        #expect(sut.presets.count == initialCount + 1)
        #expect(sut.preset(for: preset.id) != nil)
    }

    // MARK: - Update Preset Tests

    @Test mutating func updatePreset_updatesExistingPreset() {
        let preset = makeCustomPreset()
        sut.addPreset(preset)

        var updated = preset
        updated.name = "Updated Name"
        sut.updatePreset(updated)

        #expect(sut.preset(for: preset.id)?.name == "Updated Name")
    }

    @Test mutating func updatePreset_nonExistentId_noEffect() {
        let initialCount = sut.presets.count

        let preset = makeCustomPreset(id: "custom_nonexistent")
        sut.updatePreset(preset)

        #expect(sut.presets.count == initialCount)
    }

    // MARK: - Delete Preset Tests

    @Test mutating func deletePreset_removesCustomPreset() {
        let preset = makeCustomPreset()
        sut.addPreset(preset)
        let countAfterAdd = sut.presets.count

        sut.deletePreset(preset)

        #expect(sut.presets.count == countAfterAdd - 1)
        #expect(sut.preset(for: preset.id) == nil)
    }

    @Test mutating func deletePreset_builtIn_doesNotDelete() {
        let regularPreset = sut.preset(for: "regular")!
        let initialCount = sut.presets.count

        sut.deletePreset(regularPreset)

        #expect(sut.presets.count == initialCount)
        #expect(sut.preset(for: "regular") != nil)
    }

    // MARK: - Reset to Default Tests

    @Test mutating func resetToDefault_restoresBuiltInPreset() {
        // Edit the preset first
        var edited = sut.preset(for: "regular")!
        edited.name = "My Custom Regular"
        edited.isEdited = true
        sut.updatePreset(edited)
        #expect(sut.preset(for: "regular")?.name == "My Custom Regular")

        // Reset
        sut.resetToDefault(presetId: "regular")

        #expect(sut.preset(for: "regular")?.name == "Regular")
    }

    // MARK: - Favorite Tests

    @Test mutating func toggleFavorite_togglesState() {
        #expect(sut.preset(for: "regular")?.isFavorite == false)

        sut.toggleFavorite(presetId: "regular")
        #expect(sut.preset(for: "regular")?.isFavorite == true)

        sut.toggleFavorite(presetId: "regular")
        #expect(sut.preset(for: "regular")?.isFavorite == false)
    }

    @Test mutating func hasFavorites_reflectsState() {
        #expect(sut.hasFavorites == false)

        sut.toggleFavorite(presetId: "regular")
        #expect(sut.hasFavorites == true)
    }

    @Test mutating func visiblePresets_excludesHiddenPresets() {
        #expect(sut.visiblePresets.contains { $0.id == "regular" })

        sut.setPresetHidden(presetId: "regular", isHidden: true)

        #expect(!sut.visiblePresets.contains { $0.id == "regular" })
        #expect(sut.isPresetHidden(presetId: "regular") == true)
    }

    @Test mutating func hasVisibleFavorites_ignoresHiddenFavorites() {
        sut.toggleFavorite(presetId: "regular")

        #expect(sut.hasVisibleFavorites == true)

        sut.setPresetHidden(presetId: "regular", isHidden: true)

        #expect(sut.hasVisibleFavorites == false)
    }

    // MARK: - Duplicate Detection Tests

    @Test func isPresetNameDuplicate_detectsDuplicates() {
        #expect(sut.isPresetNameDuplicate("Regular") == true)
        #expect(sut.isPresetNameDuplicate("NonExistent Preset") == false)
    }

    @Test func isPresetNameDuplicate_excludesOwnId() {
        // "Regular" exists, but when excluding its own ID it should not be a duplicate
        #expect(sut.isPresetNameDuplicate("Regular", excludingId: "regular") == false)
    }

    @Test func isPresetNameDuplicate_caseInsensitive() {
        #expect(sut.isPresetNameDuplicate("regular") == true)
        #expect(sut.isPresetNameDuplicate("REGULAR") == true)
    }

    // MARK: - Persistence Tests

    // Persistence tests need a manager pair against the same defaults to
    // verify cross-instance reads, so they construct managers inline rather
    // than using the hoisted `sut`.

    @Test func persistence_presetsPersistedAcrossInstances() {
        let suiteName = "PresetManagerPersistenceTest_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: "testPresets")
        defaults.removeObject(forKey: "testHiddenPresetIDs")

        let manager1 = PresetManager(
            userDefaults: defaults,
            storageKey: "testPresets",
            hiddenPresetIDsStorageKey: "testHiddenPresetIDs"
        )
        let preset = makeCustomPreset()
        manager1.addPreset(preset)

        let manager2 = PresetManager(
            userDefaults: defaults,
            storageKey: "testPresets",
            hiddenPresetIDsStorageKey: "testHiddenPresetIDs"
        )

        #expect(manager2.preset(for: preset.id) != nil)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func persistence_hiddenPresetIDsPersistAcrossInstances() {
        let suiteName = "PresetManagerHiddenPersistenceTest_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: "testPresets")
        defaults.removeObject(forKey: "testHiddenPresetIDs")

        let manager1 = PresetManager(
            userDefaults: defaults,
            storageKey: "testPresets",
            hiddenPresetIDsStorageKey: "testHiddenPresetIDs"
        )
        manager1.setPresetHidden(presetId: "regular", isHidden: true)

        let manager2 = PresetManager(
            userDefaults: defaults,
            storageKey: "testPresets",
            hiddenPresetIDsStorageKey: "testHiddenPresetIDs"
        )

        #expect(manager2.isPresetHidden(presetId: "regular") == true)
        #expect(!manager2.visiblePresets.contains { $0.id == "regular" })

        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Sorting Tests

    @Test mutating func sorting_builtInPresetsBeforeCustom() {
        let custom = makeCustomPreset()
        sut.addPreset(custom)

        let builtInIndices = sut.presets.enumerated()
            .filter { $0.element.isBuiltIn }
            .map(\.offset)
        let customIndices = sut.presets.enumerated()
            .filter { !$0.element.isBuiltIn }
            .map(\.offset)

        if let lastBuiltIn = builtInIndices.last, let firstCustom = customIndices.first {
            #expect(lastBuiltIn < firstCustom)
        }
    }

    @Test mutating func deletePreset_removesHiddenState() {
        let preset = makeCustomPreset()
        sut.addPreset(preset)
        sut.setPresetHidden(presetId: preset.id, isHidden: true)

        sut.deletePreset(preset)

        #expect(sut.isPresetHidden(presetId: preset.id) == false)
    }

    // MARK: - Observation

    @MainActor
    @Test func addPreset_firesObservationOnPresets() async throws {
        let initialCount = sut.presets.count
        let preset = makeCustomPreset()

        try await changes(to: \.presets, on: sut, timeout: 0.5) {
            sut.addPreset(preset)
        }

        #expect(sut.presets.count == initialCount + 1)
        #expect(sut.preset(for: preset.id) != nil)
    }

    @MainActor
    @Test func deletePreset_firesObservationOnPresets() async throws {
        let preset = makeCustomPreset()
        sut.addPreset(preset)
        let countAfterAdd = sut.presets.count

        try await changes(to: \.presets, on: sut, timeout: 0.5) {
            sut.deletePreset(preset)
        }

        #expect(sut.presets.count == countAfterAdd - 1)
        #expect(sut.preset(for: preset.id) == nil)
    }
}
