//
//  PresetManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct PresetManagerTests {

    // MARK: - Test Helpers

    private func makeManager(suiteName: String = "PresetManagerTests") -> PresetManager {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: "testPresets")
        defaults.removeObject(forKey: "testHiddenPresetIDs")
        return PresetManager(
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
        let manager = makeManager()

        #expect(!manager.presets.isEmpty)
        #expect(manager.presets.contains { $0.id == "regular" })
        #expect(manager.presets.contains { $0.id == "summary" })
        #expect(manager.presets.contains { $0.id == "assistant" })
    }

    @Test func init_builtInPresetsCount_matchesCatalog() {
        let manager = makeManager()
        let builtInCount = manager.presets.filter(\.isBuiltIn).count

        #expect(builtInCount == PresetCatalog.allBuiltIn.count)
    }

    // MARK: - Lookup Tests

    @Test func preset_forId_returnsCorrectPreset() {
        let manager = makeManager()

        let preset = manager.preset(for: "regular")

        #expect(preset?.name == "Regular")
        #expect(preset?.isBuiltIn == true)
    }

    @Test func preset_forId_returnsNilForUnknownId() {
        let manager = makeManager()

        #expect(manager.preset(for: "nonexistent") == nil)
    }

    @Test func presetsInCategory_returnsFilteredPresets() {
        let manager = makeManager()

        let rewritePresets = manager.presets(in: "Rewrite")

        #expect(!rewritePresets.isEmpty)
        #expect(rewritePresets.allSatisfy { $0.category == "Rewrite" })
    }

    @Test func categories_returnsOrderedCategories() {
        let manager = makeManager()

        let categories = manager.categories

        #expect(!categories.isEmpty)
        // Rewrite should come before Translate based on categoryOrder
        if let rewriteIdx = categories.firstIndex(of: "Rewrite"),
           let translateIdx = categories.firstIndex(of: "Translate") {
            #expect(rewriteIdx < translateIdx)
        }
    }

    // MARK: - Add Preset Tests

    @Test func addPreset_addsCustomPreset() {
        let manager = makeManager()
        let initialCount = manager.presets.count
        let preset = makeCustomPreset()

        manager.addPreset(preset)

        #expect(manager.presets.count == initialCount + 1)
        #expect(manager.preset(for: preset.id) != nil)
    }

    // MARK: - Update Preset Tests

    @Test func updatePreset_updatesExistingPreset() {
        let manager = makeManager()
        let preset = makeCustomPreset()
        manager.addPreset(preset)

        var updated = preset
        updated.name = "Updated Name"
        manager.updatePreset(updated)

        #expect(manager.preset(for: preset.id)?.name == "Updated Name")
    }

    @Test func updatePreset_nonExistentId_noEffect() {
        let manager = makeManager()
        let initialCount = manager.presets.count

        let preset = makeCustomPreset(id: "custom_nonexistent")
        manager.updatePreset(preset)

        #expect(manager.presets.count == initialCount)
    }

    // MARK: - Delete Preset Tests

    @Test func deletePreset_removesCustomPreset() {
        let manager = makeManager()
        let preset = makeCustomPreset()
        manager.addPreset(preset)
        let countAfterAdd = manager.presets.count

        manager.deletePreset(preset)

        #expect(manager.presets.count == countAfterAdd - 1)
        #expect(manager.preset(for: preset.id) == nil)
    }

    @Test func deletePreset_builtIn_doesNotDelete() {
        let manager = makeManager()
        let regularPreset = manager.preset(for: "regular")!
        let initialCount = manager.presets.count

        manager.deletePreset(regularPreset)

        #expect(manager.presets.count == initialCount)
        #expect(manager.preset(for: "regular") != nil)
    }

    // MARK: - Reset to Default Tests

    @Test func resetToDefault_restoresBuiltInPreset() {
        let manager = makeManager()

        // Edit the preset first
        var edited = manager.preset(for: "regular")!
        edited.name = "My Custom Regular"
        edited.isEdited = true
        manager.updatePreset(edited)
        #expect(manager.preset(for: "regular")?.name == "My Custom Regular")

        // Reset
        manager.resetToDefault(presetId: "regular")

        #expect(manager.preset(for: "regular")?.name == "Regular")
    }

    // MARK: - Favorite Tests

    @Test func toggleFavorite_togglesState() {
        let manager = makeManager()

        #expect(manager.preset(for: "regular")?.isFavorite == false)

        manager.toggleFavorite(presetId: "regular")
        #expect(manager.preset(for: "regular")?.isFavorite == true)

        manager.toggleFavorite(presetId: "regular")
        #expect(manager.preset(for: "regular")?.isFavorite == false)
    }

    @Test func hasFavorites_reflectsState() {
        let manager = makeManager()

        #expect(manager.hasFavorites == false)

        manager.toggleFavorite(presetId: "regular")
        #expect(manager.hasFavorites == true)
    }

    @Test func visiblePresets_excludesHiddenPresets() {
        let manager = makeManager()

        #expect(manager.visiblePresets.contains { $0.id == "regular" })

        manager.setPresetHidden(presetId: "regular", isHidden: true)

        #expect(!manager.visiblePresets.contains { $0.id == "regular" })
        #expect(manager.isPresetHidden(presetId: "regular") == true)
    }

    @Test func hasVisibleFavorites_ignoresHiddenFavorites() {
        let manager = makeManager()
        manager.toggleFavorite(presetId: "regular")

        #expect(manager.hasVisibleFavorites == true)

        manager.setPresetHidden(presetId: "regular", isHidden: true)

        #expect(manager.hasVisibleFavorites == false)
    }

    // MARK: - Duplicate Detection Tests

    @Test func isPresetNameDuplicate_detectsDuplicates() {
        let manager = makeManager()

        #expect(manager.isPresetNameDuplicate("Regular") == true)
        #expect(manager.isPresetNameDuplicate("NonExistent Preset") == false)
    }

    @Test func isPresetNameDuplicate_excludesOwnId() {
        let manager = makeManager()

        // "Regular" exists, but when excluding its own ID it should not be a duplicate
        #expect(manager.isPresetNameDuplicate("Regular", excludingId: "regular") == false)
    }

    @Test func isPresetNameDuplicate_caseInsensitive() {
        let manager = makeManager()

        #expect(manager.isPresetNameDuplicate("regular") == true)
        #expect(manager.isPresetNameDuplicate("REGULAR") == true)
    }

    // MARK: - Persistence Tests

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

    @Test func sorting_builtInPresetsBeforeCustom() {
        let manager = makeManager()
        let custom = makeCustomPreset()
        manager.addPreset(custom)

        let builtInIndices = manager.presets.enumerated()
            .filter { $0.element.isBuiltIn }
            .map(\.offset)
        let customIndices = manager.presets.enumerated()
            .filter { !$0.element.isBuiltIn }
            .map(\.offset)

        if let lastBuiltIn = builtInIndices.last, let firstCustom = customIndices.first {
            #expect(lastBuiltIn < firstCustom)
        }
    }

    @Test func deletePreset_removesHiddenState() {
        let manager = makeManager()
        let preset = makeCustomPreset()
        manager.addPreset(preset)
        manager.setPresetHidden(presetId: preset.id, isHidden: true)

        manager.deletePreset(preset)

        #expect(manager.isPresetHidden(presetId: preset.id) == false)
    }
}
