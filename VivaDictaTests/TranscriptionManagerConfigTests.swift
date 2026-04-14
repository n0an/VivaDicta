//
//  TranscriptionManagerConfigTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct TranscriptionManagerConfigTests {

    // MARK: - Test Helpers

    private func makeMode(
        name: String = "Test",
        provider: TranscriptionModelProvider = .whisperKit,
        model: String = "test-model",
        language: String? = "en"
    ) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: name,
            transcriptionProvider: provider,
            transcriptionModel: model,
            transcriptionLanguage: language,
            aiModel: "",
            aiEnhanceEnabled: false
        )
    }

    // MARK: - Set Current Mode

    @Test func setCurrentMode_updatesMode() {
        let manager = TranscriptionManager()
        let mode = makeMode(name: "Custom Mode")

        manager.setCurrentMode(mode)

        #expect(manager.currentMode.name == "Custom Mode")
    }

    @Test func setCurrentMode_appliesLanguage() {
        let manager = TranscriptionManager()
        let mode = makeMode(language: "es")

        manager.setCurrentMode(mode)

        #expect(manager.selectedLanguage == "es")
    }

    @Test func setCurrentMode_nilLanguage_defaultsToAuto() {
        let manager = TranscriptionManager()
        let mode = makeMode(language: nil)

        manager.setCurrentMode(mode)

        #expect(manager.selectedLanguage == "auto")
    }

    // MARK: - Get Current Model

    @Test func getCurrentModel_defaultMode_returnsNil() {
        // Default mode has empty transcriptionModel → no match
        let manager = TranscriptionManager()

        let model = manager.getCurrentTranscriptionModel()

        #expect(model == nil)
    }

    @Test func getCurrentModel_invalidModel_returnsNil() {
        let manager = TranscriptionManager()
        let mode = makeMode(model: "nonexistent-model-xyz")
        manager.setCurrentMode(mode)

        let model = manager.getCurrentTranscriptionModel()

        #expect(model == nil)
    }

    // MARK: - Update Cloud Models

    @Test func updateCloudModels_firesCallback() {
        let manager = TranscriptionManager()
        var callbackFired = false
        manager.onCloudModelsUpdate = { callbackFired = true }

        manager.updateCloudModels()

        #expect(callbackFired == true)
    }

    @Test func updateCloudModels_rebuildsModelList() {
        let manager = TranscriptionManager()
        let countBefore = manager.allAvailableModels.count

        manager.updateCloudModels()

        // Should repopulate (count may be same but list was rebuilt)
        #expect(manager.allAvailableModels.count == countBefore)
    }
}

struct MistralTranscriptionServiceTests {

    @Test func requestLanguage_keepsExplicitLanguageWhenDiarizationDisabled() {
        let requestLanguage = MistralTranscriptionService.requestLanguage(
            for: "en",
            diarizationEnabled: false
        )

        #expect(requestLanguage == "en")
    }

    @Test func requestLanguage_skipsExplicitLanguageWhenDiarizationEnabled() {
        let requestLanguage = MistralTranscriptionService.requestLanguage(
            for: "en",
            diarizationEnabled: true
        )

        #expect(requestLanguage == nil)
    }
}
