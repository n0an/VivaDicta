//
//  AIServiceModeTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct AIServiceModeTests {

    // MARK: - Test Helpers

    private let suiteName = "AIServiceModeTests.\(UUID().uuidString)"

    private func makeService() -> AIService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AIService(userDefaults: defaults)
    }

    private func makeService(withModes modes: [VivaMode]) -> AIService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        // Pre-seed modes into UserDefaults
        let encoded = try! JSONEncoder().encode(modes)
        defaults.set(encoded, forKey: "VivaModes")
        return AIService(userDefaults: defaults)
    }

    private func makeMode(
        name: String = "Test Mode",
        aiProvider: AIProvider? = .groq,
        aiModel: String = "test-model",
        aiEnhanceEnabled: Bool = true,
        presetId: String? = "regular"
    ) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: name,
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test-whisper",
            presetId: presetId,
            aiProvider: aiProvider,
            aiModel: aiModel,
            aiEnhanceEnabled: aiEnhanceEnabled
        )
    }

    // MARK: - Add Mode Tests

    @Test func addMode_appendsToList() {
        let service = makeService()
        let initialCount = service.modes.count
        let newMode = makeMode(name: "New Mode")

        service.addMode(newMode)

        #expect(service.modes.count == initialCount + 1)
        #expect(service.modes.last?.name == "New Mode")
    }

    @Test func addMode_persists() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let newMode = makeMode(name: "Persisted Mode")

        // Add mode with first service instance
        let service1 = AIService(userDefaults: defaults)
        service1.addMode(newMode)

        // Create fresh service reading from same UserDefaults
        let service2 = AIService(userDefaults: defaults)

        #expect(service2.modes.contains { $0.name == "Persisted Mode" })
    }

    // MARK: - Update Mode Tests

    @Test func updateMode_updatesExistingById() {
        let mode = makeMode(name: "Original")
        let service = makeService(withModes: [mode])

        let updated = VivaMode(
            id: mode.id,
            name: "Updated",
            transcriptionProvider: mode.transcriptionProvider,
            transcriptionModel: mode.transcriptionModel,
            presetId: mode.presetId,
            aiProvider: mode.aiProvider,
            aiModel: mode.aiModel,
            aiEnhanceEnabled: mode.aiEnhanceEnabled
        )

        service.updateMode(updated)

        #expect(service.modes.first?.name == "Updated")
    }

    @Test func updateMode_updatesSelectedModeIfMatching() {
        let mode = makeMode(name: "Selected")
        let service = makeService(withModes: [mode])
        service.selectedModeName = mode.name

        let updated = VivaMode(
            id: mode.id,
            name: "Selected",
            transcriptionProvider: mode.transcriptionProvider,
            transcriptionModel: mode.transcriptionModel,
            presetId: mode.presetId,
            aiProvider: .anthropic,
            aiModel: "claude-sonnet-4-6",
            aiEnhanceEnabled: mode.aiEnhanceEnabled
        )

        service.updateMode(updated)

        #expect(service.selectedMode.aiModel == "claude-sonnet-4-6")
    }

    @Test func updateMode_nonExistentId_noOp() {
        let existing = makeMode(name: "Existing")
        let service = makeService(withModes: [existing])
        let unrelated = makeMode(name: "Ghost")

        service.updateMode(unrelated)

        #expect(service.modes.count == 1)
        #expect(service.modes.first?.name == "Existing")
    }

    // MARK: - Delete Mode Tests

    @Test func deleteMode_removesFromList() {
        let mode1 = makeMode(name: "Mode 1")
        let mode2 = makeMode(name: "Mode 2")
        let service = makeService(withModes: [mode1, mode2])

        service.deleteMode(mode1)

        #expect(service.modes.count == 1)
        #expect(service.modes.first?.name == "Mode 2")
    }

    @Test func deleteMode_lastMode_blocked() {
        let onlyMode = makeMode(name: "Only")
        let service = makeService(withModes: [onlyMode])

        service.deleteMode(onlyMode)

        #expect(service.modes.count == 1)
        #expect(service.modes.first?.name == "Only")
    }

    @Test func deleteMode_selectedMode_switchesToFirst() {
        let mode1 = makeMode(name: "First")
        let mode2 = makeMode(name: "Second")
        let service = makeService(withModes: [mode1, mode2])
        service.selectedModeName = mode2.name

        service.deleteMode(mode2)

        #expect(service.selectedModeName == "First")
    }

    // MARK: - Duplicate Mode Tests

    @Test func duplicateMode_createsNewId() {
        let original = makeMode(name: "Original")
        let service = makeService(withModes: [original])

        service.duplicateMode(original)

        #expect(service.modes.count == 2)
        let duplicated = service.modes.last!
        #expect(duplicated.id != original.id)
    }

    @Test func duplicateMode_generatesUniqueName() {
        let original = makeMode(name: "Original")
        let service = makeService(withModes: [original])

        service.duplicateMode(original)

        let duplicated = service.modes.last!
        #expect(duplicated.name == "Original 1")
    }

    @Test func duplicateMode_copiesAllProperties() {
        let original = VivaMode(
            id: UUID(),
            name: "Full Mode",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "large-v3",
            transcriptionLanguage: "en",
            presetId: "summary",
            aiProvider: .anthropic,
            aiModel: "claude-sonnet-4-6",
            aiEnhanceEnabled: true,
            useClipboardContext: true,
            isAutoTextFormattingEnabled: true,
            isSmartInsertEnabled: true
        )
        let service = makeService(withModes: [original])

        service.duplicateMode(original)

        let dup = service.modes.last!
        #expect(dup.transcriptionProvider == original.transcriptionProvider)
        #expect(dup.transcriptionModel == original.transcriptionModel)
        #expect(dup.transcriptionLanguage == original.transcriptionLanguage)
        #expect(dup.presetId == original.presetId)
        #expect(dup.aiProvider == original.aiProvider)
        #expect(dup.aiModel == original.aiModel)
        #expect(dup.aiEnhanceEnabled == original.aiEnhanceEnabled)
        #expect(dup.useClipboardContext == original.useClipboardContext)

        #expect(dup.isAutoTextFormattingEnabled == original.isAutoTextFormattingEnabled)
        #expect(dup.isSmartInsertEnabled == original.isSmartInsertEnabled)
    }

    // MARK: - Generate Unique Name Tests

    @Test func generateUniqueName_incrementsCorrectly() {
        let mode1 = makeMode(name: "Mode")
        let service = makeService(withModes: [mode1])

        // First duplicate: "Mode" → "Mode 1"
        service.duplicateMode(mode1)
        #expect(service.modes.last?.name == "Mode 1")

        // Second duplicate of original: "Mode" → "Mode 2" (since "Mode 1" exists)
        service.duplicateMode(mode1)
        #expect(service.modes.last?.name == "Mode 2")
    }

    @Test func generateUniqueName_duplicateOfDuplicate() {
        let mode1 = makeMode(name: "Mode")
        let service = makeService(withModes: [mode1])

        service.duplicateMode(mode1)
        let dup1 = service.modes.last!
        // dup1.name == "Mode 1"

        // Duplicate "Mode 1" → extracts base "Mode", sees "Mode" and "Mode 1" exist → "Mode 2"
        service.duplicateMode(dup1)
        #expect(service.modes.last?.name == "Mode 2")
    }

    // MARK: - GetMode Tests

    @Test func getMode_existingName_returnsMode() {
        let mode = makeMode(name: "Specific")
        let service = makeService(withModes: [mode])

        let found = service.getMode(name: "Specific")

        #expect(found.id == mode.id)
    }

    @Test func getMode_nonExistentName_returnsDefault() {
        let service = makeService()

        let found = service.getMode(name: "DoesNotExist")

        #expect(found.name == VivaMode.defaultMode.name)
    }
}
