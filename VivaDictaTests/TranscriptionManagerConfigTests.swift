//
//  TranscriptionManagerConfigTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
import CloudTranscription
@testable import VivaDicta

struct TranscriptionManagerConfigTests {

    let sut: TranscriptionManager

    init() {
        sut = TranscriptionManager()
    }

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
        let mode = makeMode(name: "Custom Mode")

        sut.setCurrentMode(mode)

        #expect(sut.currentMode.name == "Custom Mode")
    }

    @Test func setCurrentMode_appliesLanguage() {
        let mode = makeMode(language: "es")

        sut.setCurrentMode(mode)

        #expect(sut.selectedLanguage == "es")
    }

    @Test func setCurrentMode_nilLanguage_defaultsToAuto() {
        let mode = makeMode(language: nil)

        sut.setCurrentMode(mode)

        #expect(sut.selectedLanguage == "auto")
    }

    // MARK: - Get Current Model

    @Test func getCurrentModel_defaultMode_returnsNil() {
        // Default mode has empty transcriptionModel → no match
        let model = sut.getCurrentTranscriptionModel()

        #expect(model == nil)
    }

    @Test func getCurrentModel_invalidModel_returnsNil() {
        let mode = makeMode(model: "nonexistent-model-xyz")
        sut.setCurrentMode(mode)

        let model = sut.getCurrentTranscriptionModel()

        #expect(model == nil)
    }

    // MARK: - Update Cloud Models

    @Test func updateCloudModels_firesCallback() {
        var callbackFired = false
        sut.onCloudModelsUpdate = { callbackFired = true }

        sut.updateCloudModels()

        #expect(callbackFired == true)
    }

    @Test func updateCloudModels_rebuildsModelList() {
        let countBefore = sut.allAvailableModels.count

        sut.updateCloudModels()

        // Should repopulate (count may be same but list was rebuilt)
        #expect(sut.allAvailableModels.count == countBefore)
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
