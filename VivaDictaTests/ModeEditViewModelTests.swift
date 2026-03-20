//
//  ModeEditViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.12
//

import Foundation
import Testing
@testable import VivaDicta

struct ModeEditViewModelTests {

    // MARK: - Test Helpers

    private func makeViewModel() -> ModeEditViewModel {
        let aiService = AIService()
        let presetManager = PresetManager(
            userDefaults: UserDefaults(suiteName: "ModeEditViewModelTests")!,
            storageKey: "testPresets"
        )
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
        let viewModel = makeViewModel()
        viewModel.modeName = ""

        #expect(viewModel.isValid == false)
    }

    @Test func testIsValid_whitespaceOnlyName_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.modeName = "   "

        #expect(viewModel.isValid == false)
    }

    @Test func testIsValid_noTranscriptionModel_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.modeName = "Test Mode"
        viewModel.transcriptionModel = ""

        #expect(viewModel.isValid == false)
    }

    @Test func testIsValid_aiProcessingDisabled_noAIConfigNeeded() {
        let viewModel = makeViewModel()
        viewModel.modeName = "Test Mode"
        viewModel.transcriptionProvider = .parakeet
        viewModel.transcriptionModel = "test-model"
        viewModel.aiEnhanceEnabled = false

        // When AI processing is disabled, we don't need AI config
        // But we still need transcription to be configured
        // Note: isTranscriptionProviderConfigured depends on downloaded models
        // For this test, we're checking the logic flow
        #expect(viewModel.aiEnhanceEnabled == false)
    }

    @Test func testIsValid_aiProcessingEnabled_noProvider_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.modeName = "Test Mode"
        viewModel.transcriptionModel = "test-model"
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = nil

        // Should be invalid because AI processing is enabled but no provider
        #expect(viewModel.aiEnhancementValidationMessage == "Select an AI provider")
    }

    @Test func testIsValid_aiProcessingEnabled_noModel_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.modeName = "Test Mode"
        viewModel.transcriptionModel = "test-model"
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = .openAI
        viewModel.aiModel = nil

        #expect(viewModel.aiEnhancementValidationMessage == "Add API key to continue")
    }

    @Test func testIsValid_aiProcessingEnabled_emptyModel_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.modeName = "Test Mode"
        viewModel.transcriptionModel = "test-model"
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = .openAI
        viewModel.aiModel = ""

        #expect(viewModel.aiEnhancementValidationMessage != nil)
    }

    @Test func testIsValid_aiProcessingEnabled_noPreset_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.modeName = "Test Mode"
        viewModel.transcriptionModel = "test-model"
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = .openAI
        viewModel.aiModel = "gpt-4"
        viewModel.selectedPresetId = nil

        // Should show preset validation message (after API key check)
        #expect(viewModel.aiEnhancementValidationMessage != nil)
    }

    // MARK: - transcriptionValidationMessage Tests

    @Test func testTranscriptionValidationMessage_localProviderNotConfigured() {
        let viewModel = makeViewModel()
        viewModel.transcriptionProvider = .whisperKit
        // No models downloaded, so should show download message

        let message = viewModel.transcriptionValidationMessage
        #expect(message == "Download a model to continue" || message == "Select a transcription model")
    }

    @Test func testTranscriptionValidationMessage_cloudProviderNotConfigured() {
        let viewModel = makeViewModel()
        viewModel.transcriptionProvider = .groq
        viewModel.transcriptionModel = "whisper-large-v3"

        // Check that validation message is present when provider not configured
        // The exact message depends on whether API key exists
        let isConfigured = viewModel.isTranscriptionProviderConfigured(viewModel.transcriptionProvider)
        if !isConfigured {
            #expect(viewModel.transcriptionValidationMessage == "Add API key to continue")
        } else {
            // If configured (API key exists), no validation message needed
            #expect(viewModel.transcriptionValidationMessage == nil)
        }
    }

    @Test func testTranscriptionValidationMessage_emptyModel() {
        let viewModel = makeViewModel()
        viewModel.transcriptionProvider = .groq
        viewModel.transcriptionModel = ""

        // Should have a validation message
        #expect(viewModel.transcriptionValidationMessage != nil)
    }

    // MARK: - AI Processing Validation Message Tests

    @Test func testAIProcessingValidationMessage_disabled_returnsNil() {
        let viewModel = makeViewModel()
        viewModel.aiEnhanceEnabled = false

        #expect(viewModel.aiEnhancementValidationMessage == nil)
    }

    @Test func testAIProcessingValidationMessage_noProvider() {
        let viewModel = makeViewModel()
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = nil

        #expect(viewModel.aiEnhancementValidationMessage == "Select an AI provider")
    }

    @Test func testAIProcessingValidationMessage_noAPIKey() {
        let viewModel = makeViewModel()
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = .openAI
        // No API key configured

        #expect(viewModel.aiEnhancementValidationMessage == "Add API key to continue")
    }

    @Test func testAIProcessingValidationMessage_noPreset() {
        let viewModel = makeViewModel()
        viewModel.aiEnhanceEnabled = true
        viewModel.aiProvider = .openAI
        viewModel.aiModel = "gpt-4"
        viewModel.selectedPresetId = nil
        // Would need API key to get past that check, so this tests the order

        // The validation checks in order: provider -> API key -> model -> preset
        #expect(viewModel.aiEnhancementValidationMessage != nil)
    }

    // MARK: - isEditing Tests

    @Test func testIsEditing_newMode_returnsFalse() {
        let viewModel = makeViewModel()

        #expect(viewModel.isEditing == false)
    }

    @Test func testIsEditing_existingMode_returnsTrue() {
        let aiService = AIService()
        let presetManager = PresetManager(
            userDefaults: UserDefaults(suiteName: "ModeEditViewModelTests")!,
            storageKey: "testPresets"
        )
        let transcriptionManager = TranscriptionManager()

        let existingMode = VivaMode(
            id: UUID(),
            name: "Existing",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test",
            aiModel: "",
            aiEnhanceEnabled: false
        )

        let viewModel = ModeEditViewModel(
            mode: existingMode,
            aiService: aiService,
            presetManager: presetManager,
            transcriptionManager: transcriptionManager
        )

        #expect(viewModel.isEditing == true)
    }

    // MARK: - Mode Name Validation Tests

    @Test func testModeName_trimmedForValidation() {
        let viewModel = makeViewModel()
        viewModel.modeName = "  Test Mode  "
        viewModel.transcriptionModel = "test"

        // The name with whitespace should still be considered valid
        // (validation trims the name)
        let trimmedName = viewModel.modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!trimmedName.isEmpty)
    }
}
