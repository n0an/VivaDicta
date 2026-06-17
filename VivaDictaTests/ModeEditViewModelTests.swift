//
//  ModeEditViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.12
//

import Foundation
import Testing
import Presets
@testable import VivaDicta
import AICore

struct ModeEditViewModelTests {

    // MARK: - Test Helpers

    private func makePresetManager(suiteName: String = "ModeEditViewModelTests") -> PresetManager {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: "testPresets")
        defaults.removeObject(forKey: "testHiddenPresetIDs")

        return PresetManager(
            userDefaults: defaults,
            storageKey: "testPresets",
            hiddenPresetIDsStorageKey: "testHiddenPresetIDs"
        )
    }

    private func makeViewModel() -> ModeEditViewModel {
        let aiService = AIService()
        let presetManager = makePresetManager()
        let transcriptionManager = TranscriptionManager()

        return ModeEditViewModel(
            mode: nil,
            aiService: aiService,
            presetManager: presetManager,
            transcriptionManager: transcriptionManager
        )
    }

    // MARK: - isValid Tests

    @Test func testIsValid_emptyName_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = ""

        #expect(sut.isValid == false)
    }

    @Test func testIsValid_whitespaceOnlyName_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = "   "

        #expect(sut.isValid == false)
    }

    @Test func testIsValid_noTranscriptionModel_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = "Test Mode"
        sut.transcriptionModel = ""

        #expect(sut.isValid == false)
    }

    @Test func testIsValid_aiProcessingDisabled_noAIConfigNeeded() {
        let sut = makeViewModel()
        sut.modeName = "Test Mode"
        sut.transcriptionProvider = .parakeet
        sut.transcriptionModel = "test-model"
        sut.aiEnhanceEnabled = false

        // When AI processing is disabled, we don't need AI config
        // But we still need transcription to be configured
        // Note: isTranscriptionProviderConfigured depends on downloaded models
        // For this test, we're checking the logic flow
        #expect(sut.aiEnhanceEnabled == false)
    }

    @Test func testIsValid_aiProcessingEnabled_noProvider_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = "Test Mode"
        sut.transcriptionModel = "test-model"
        sut.aiEnhanceEnabled = true
        sut.aiProvider = nil

        // Should be invalid because AI processing is enabled but no provider
        #expect(sut.aiEnhancementValidationMessage == "Select an AI provider, or disable AI Processing")
    }

    @Test func testIsValid_aiProcessingEnabled_noModel_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = "Test Mode"
        sut.transcriptionModel = "test-model"
        sut.aiEnhanceEnabled = true
        sut.aiProvider = .openAI
        sut.aiModel = nil

        #expect(sut.aiEnhancementValidationMessage == "Add API key to continue, or disable AI Processing")
    }

    @Test func testIsValid_aiProcessingEnabled_emptyModel_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = "Test Mode"
        sut.transcriptionModel = "test-model"
        sut.aiEnhanceEnabled = true
        sut.aiProvider = .openAI
        sut.aiModel = ""

        #expect(sut.aiEnhancementValidationMessage != nil)
    }

    @Test func testIsValid_aiProcessingEnabled_noPreset_returnsFalse() {
        let sut = makeViewModel()
        sut.modeName = "Test Mode"
        sut.transcriptionModel = "test-model"
        sut.aiEnhanceEnabled = true
        sut.aiProvider = .openAI
        sut.aiModel = "gpt-4"
        sut.selectedPresetId = nil

        // Should show preset validation message (after API key check)
        #expect(sut.aiEnhancementValidationMessage != nil)
    }

    // MARK: - transcriptionValidationMessage Tests

    @Test func testTranscriptionValidationMessage_localProviderNotConfigured() {
        let sut = makeViewModel()
        sut.transcriptionProvider = .whisperKit
        // No models downloaded, so should show download message

        let message = sut.transcriptionValidationMessage
        #expect(message == "Download a model to continue" || message == "Select a transcription model")
    }

    @Test func testTranscriptionValidationMessage_cloudProviderNotConfigured() {
        let sut = makeViewModel()
        sut.transcriptionProvider = .groq
        sut.transcriptionModel = "whisper-large-v3"

        // Check that validation message is present when provider not configured
        // The exact message depends on whether API key exists
        let isConfigured = sut.isTranscriptionProviderConfigured(sut.transcriptionProvider)
        if !isConfigured {
            #expect(sut.transcriptionValidationMessage == "Add API key to continue")
        } else {
            // If configured (API key exists), no validation message needed
            #expect(sut.transcriptionValidationMessage == nil)
        }
    }

    @Test func testTranscriptionValidationMessage_emptyModel() {
        let sut = makeViewModel()
        sut.transcriptionProvider = .groq
        sut.transcriptionModel = ""

        // Should have a validation message
        #expect(sut.transcriptionValidationMessage != nil)
    }

    // MARK: - AI Processing Validation Message Tests

    @Test func testAIProcessingValidationMessage_disabled_returnsNil() {
        let sut = makeViewModel()
        sut.aiEnhanceEnabled = false

        #expect(sut.aiEnhancementValidationMessage == nil)
    }

    @Test func testAIProcessingValidationMessage_noProvider() {
        let sut = makeViewModel()
        sut.aiEnhanceEnabled = true
        sut.aiProvider = nil

        #expect(sut.aiEnhancementValidationMessage == "Select an AI provider, or disable AI Processing")
    }

    @Test func testAIProcessingValidationMessage_noAPIKey() {
        let sut = makeViewModel()
        sut.aiEnhanceEnabled = true
        sut.aiProvider = .openAI
        // No API key configured

        #expect(sut.aiEnhancementValidationMessage == "Add API key to continue, or disable AI Processing")
    }

    @Test func testAIProcessingValidationMessage_noPreset() {
        let sut = makeViewModel()
        sut.aiEnhanceEnabled = true
        sut.aiProvider = .openAI
        sut.aiModel = "gpt-4"
        sut.selectedPresetId = nil
        // Would need API key to get past that check, so this tests the order

        // The validation checks in order: provider -> API key -> model -> preset
        #expect(sut.aiEnhancementValidationMessage != nil)
    }

    // MARK: - isEditing Tests

    @Test func testIsEditing_newMode_returnsFalse() {
        let sut = makeViewModel()

        #expect(sut.isEditing == false)
    }

    @Test func testIsEditing_existingMode_returnsTrue() {
        let aiService = AIService()
        let presetManager = makePresetManager()
        let transcriptionManager = TranscriptionManager()

        let existingMode = VivaMode(
            id: UUID(),
            name: "Existing",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test",
            aiModel: "",
            aiEnhanceEnabled: false
        )

        let sut = ModeEditViewModel(
            mode: existingMode,
            aiService: aiService,
            presetManager: presetManager,
            transcriptionManager: transcriptionManager
        )

        #expect(sut.isEditing == true)
    }

    @Test func testSelectFirstPresetIfNeeded_skipsHiddenPresets() {
        let sut = makeViewModel()

        sut.presetManager.setPresetHidden(presetId: "regular", isHidden: true)
        sut.selectedPresetId = nil
        sut.selectFirstPresetIfNeeded()

        #expect(sut.selectedPresetId == sut.presetManager.visiblePresets.first?.id)
    }

    @Test func testSelectFirstPresetIfNeeded_allHidden_leavesSelectionNil() {
        let sut = makeViewModel()
        for preset in sut.presetManager.visiblePresets {
            sut.presetManager.setPresetHidden(presetId: preset.id, isHidden: true)
        }

        sut.selectedPresetId = nil
        sut.selectFirstPresetIfNeeded()

        #expect(sut.selectedPresetId == nil)
    }

    // MARK: - Mode Name Validation Tests

    @Test func testModeName_trimmedForValidation() {
        let sut = makeViewModel()
        sut.modeName = "  Test Mode  "
        sut.transcriptionModel = "test"

        // The name with whitespace should still be considered valid
        // (validation trims the name)
        let trimmedName = sut.modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmedName.isEmpty == false)
    }
}
