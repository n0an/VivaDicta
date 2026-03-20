//
//  PresetTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct PresetTests {

    // MARK: - Initialization Tests

    @Test func init_setsAllProperties() {
        let date = Date()
        let preset = Preset(
            id: "test",
            name: "Test",
            icon: "🧪",
            presetDescription: "A test preset",
            category: "Other",
            promptInstructions: "Test instructions",
            useSystemTemplate: true,
            wrapInTranscriptTags: true,
            isBuiltIn: false,
            isEdited: false,
            isFavorite: true,
            createdAt: date
        )

        #expect(preset.id == "test")
        #expect(preset.name == "Test")
        #expect(preset.icon == "🧪")
        #expect(preset.presetDescription == "A test preset")
        #expect(preset.category == "Other")
        #expect(preset.promptInstructions == "Test instructions")
        #expect(preset.useSystemTemplate == true)
        #expect(preset.wrapInTranscriptTags == true)
        #expect(preset.isBuiltIn == false)
        #expect(preset.isEdited == false)
        #expect(preset.isFavorite == true)
        #expect(preset.createdAt == date)
    }

    @Test func init_defaults() {
        let preset = Preset(
            id: "test",
            name: "Test",
            icon: "🧪",
            category: "Other",
            promptInstructions: "Instructions",
            useSystemTemplate: true
        )

        #expect(preset.presetDescription == "")
        #expect(preset.wrapInTranscriptTags == true)
        #expect(preset.isBuiltIn == false)
        #expect(preset.isEdited == false)
        #expect(preset.isFavorite == false)
    }

    // MARK: - Codable Tests

    @Test func codable_roundTrip() throws {
        let original = Preset(
            id: "test_codable",
            name: "Codable Test",
            icon: "📦",
            presetDescription: "Testing codable",
            category: "Other",
            promptInstructions: "Encode and decode me",
            useSystemTemplate: false,
            wrapInTranscriptTags: false,
            isBuiltIn: true,
            isEdited: true,
            isFavorite: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Preset.self, from: data)

        #expect(decoded == original)
    }

    @Test func decodable_handlesMissingOptionalFields() throws {
        // Simulate JSON without presetDescription and isFavorite (added later)
        let json = """
        {
            "id": "test",
            "name": "Test",
            "icon": "🧪",
            "category": "Other",
            "promptInstructions": "Instructions",
            "useSystemTemplate": true,
            "wrapInTranscriptTags": true,
            "isBuiltIn": false,
            "isEdited": false,
            "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Preset.self, from: json)

        #expect(decoded.presetDescription == "")
        #expect(decoded.isFavorite == false)
    }

    // MARK: - Equatable Tests

    @Test func equatable_sameProperties_areEqual() {
        let date = Date()
        let preset1 = Preset(id: "a", name: "A", icon: "🅰️", category: "X",
                             promptInstructions: "Do A", useSystemTemplate: true, createdAt: date)
        let preset2 = Preset(id: "a", name: "A", icon: "🅰️", category: "X",
                             promptInstructions: "Do A", useSystemTemplate: true, createdAt: date)

        #expect(preset1 == preset2)
    }

    @Test func equatable_differentProperties_areNotEqual() {
        let date = Date()
        let preset1 = Preset(id: "a", name: "A", icon: "🅰️", category: "X",
                             promptInstructions: "Do A", useSystemTemplate: true, createdAt: date)
        let preset2 = Preset(id: "b", name: "B", icon: "🅱️", category: "X",
                             promptInstructions: "Do B", useSystemTemplate: true, createdAt: date)

        #expect(preset1 != preset2)
    }

    // MARK: - iconIsEmoji Tests

    @Test func iconIsEmoji_emojiReturnsTrue() {
        let preset = Preset(id: "test", name: "Test", icon: "✨", category: "X",
                            promptInstructions: "", useSystemTemplate: true)

        #expect(preset.iconIsEmoji == true)
    }

    @Test func iconIsEmoji_assetPrefixReturnsFalse() {
        let preset = Preset(id: "test", name: "Test", icon: "asset:instagram", category: "X",
                            promptInstructions: "", useSystemTemplate: true)

        #expect(preset.iconIsEmoji == false)
    }
}
