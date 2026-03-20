//
//  PresetCatalogTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct PresetCatalogTests {

    // MARK: - Built-In Preset Integrity

    @Test func allBuiltIn_haveUniqueIds() {
        let ids = PresetCatalog.allBuiltIn.map(\.id)
        let uniqueIds = Set(ids)

        #expect(ids.count == uniqueIds.count)
    }

    @Test func allBuiltIn_haveNonEmptyNames() {
        for preset in PresetCatalog.allBuiltIn {
            #expect(!preset.name.isEmpty, "Preset \(preset.id) has empty name")
        }
    }

    @Test func allBuiltIn_haveNonEmptyPromptInstructions() {
        for preset in PresetCatalog.allBuiltIn {
            #expect(!preset.promptInstructions.isEmpty, "Preset \(preset.id) has empty instructions")
        }
    }

    @Test func allBuiltIn_haveNonEmptyIcons() {
        for preset in PresetCatalog.allBuiltIn {
            #expect(!preset.icon.isEmpty, "Preset \(preset.id) has empty icon")
        }
    }

    @Test func allBuiltIn_areMarkedAsBuiltIn() {
        for preset in PresetCatalog.allBuiltIn {
            #expect(preset.isBuiltIn, "Preset \(preset.id) is not marked as built-in")
        }
    }

    @Test func allBuiltIn_haveValidCategories() {
        let validCategories = Set(PresetCatalog.categoryOrder)
        for preset in PresetCatalog.allBuiltIn {
            #expect(validCategories.contains(preset.category),
                    "Preset \(preset.id) has unknown category: \(preset.category)")
        }
    }

    // MARK: - builtInIds Set

    @Test func builtInIds_matchesAllBuiltInCount() {
        #expect(PresetCatalog.builtInIds.count == PresetCatalog.allBuiltIn.count)
    }

    // MARK: - CloudKit UUID Mapping

    @Test func builtInUUIDs_allBuiltInPresetsHaveUUIDs() {
        for preset in PresetCatalog.allBuiltIn {
            #expect(PresetCatalog.builtInUUIDs[preset.id] != nil,
                    "Built-in preset \(preset.id) missing CloudKit UUID")
        }
    }

    @Test func builtInUUIDs_allUniqueUUIDs() {
        let uuids = Array(PresetCatalog.builtInUUIDs.values)
        let uniqueUUIDs = Set(uuids)

        #expect(uuids.count == uniqueUUIDs.count)
    }

    @Test func uuid_roundTrip_idToUUIDAndBack() {
        for (presetId, uuid) in PresetCatalog.builtInUUIDs {
            let resolvedId = PresetCatalog.presetId(for: uuid)
            #expect(resolvedId == presetId, "UUID round-trip failed for \(presetId)")
        }
    }

    // MARK: - Lookup Functions

    @Test func defaultPreset_returnsCorrectPreset() {
        let preset = PresetCatalog.defaultPreset(for: "regular")

        #expect(preset?.name == "Regular")
        #expect(preset?.category == "Rewrite")
    }

    @Test func defaultPreset_returnsNilForUnknownId() {
        #expect(PresetCatalog.defaultPreset(for: "nonexistent") == nil)
    }

    @Test func icon_returnsCorrectIconForBuiltIn() {
        #expect(PresetCatalog.icon(for: "regular") == "✨")
        #expect(PresetCatalog.icon(for: "email") == "📧")
    }

    @Test func icon_returnsFallbackForUnknownId() {
        #expect(PresetCatalog.icon(for: "nonexistent") == "✨")
    }

    // MARK: - Category Ordering

    @Test func categories_orderedCorrectly() {
        let categories = PresetCatalog.categories

        if let rewriteIdx = categories.firstIndex(of: "Rewrite"),
           let summarizeIdx = categories.firstIndex(of: "Summarize"),
           let translateIdx = categories.firstIndex(of: "Translate") {
            #expect(rewriteIdx < summarizeIdx)
            #expect(summarizeIdx < translateIdx)
        }
    }

    // MARK: - Stable UUID Regression Tests

    @Test func stableUUIDs_regularPresetUUIDNeverChanges() {
        #expect(PresetCatalog.builtInUUIDs["regular"] == UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    }

    @Test func stableUUIDs_assistantPresetUUIDNeverChanges() {
        #expect(PresetCatalog.builtInUUIDs["assistant"] == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
    }

    @Test func stableUUIDs_summaryPresetUUIDNeverChanges() {
        #expect(PresetCatalog.builtInUUIDs["summary"] == UUID(uuidString: "00000000-0000-0000-0000-000000000010"))
    }

    // MARK: - Assistant Preset Special Behavior

    @Test func assistantPreset_usesStandaloneSystemMessage() {
        #expect(PresetCatalog.assistant.useSystemTemplate == false)
    }

    @Test func nonAssistantPresets_useSystemTemplate() {
        let nonAssistant = PresetCatalog.allBuiltIn.filter { $0.id != "assistant" }
        for preset in nonAssistant {
            #expect(preset.useSystemTemplate == true, "Preset \(preset.id) should use system template")
        }
    }
}
