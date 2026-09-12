//
//  VivaModeSpeakerLabelsTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.09.12
//

import Foundation
import Testing
import AppGroup
@testable import VivaDicta

/// Serialized because the legacy-inheritance path reads the one shared
/// `AppGroupCoordinator`, and these tests move that value out from under it.
@Suite(.serialized)
struct VivaModeSpeakerLabelsTests {

    private func modePayload(speakerLabels: Bool?) -> Data {
        var payload: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Meetings",
            "transcriptionProvider": "deepgram",
            "transcriptionModel": "nova-3",
            "aiModel": "",
            "aiEnhanceEnabled": false
        ]
        if let speakerLabels {
            payload["speakerLabelsEnabled"] = speakerLabels
        }
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    private func withLegacyGlobal(_ value: Bool, _ body: () throws -> Void) rethrows {
        let original = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled
        AppGroupCoordinator.shared.isSpeakerDiarizationEnabled = value
        defer { AppGroupCoordinator.shared.isSpeakerDiarizationEnabled = original }
        try body()
    }

    // MARK: - Decoding

    @Test func decode_usesTheModesOwnFlagWhenPresent() throws {
        try withLegacyGlobal(false) {
            let decoded = try JSONDecoder().decode(VivaMode.self, from: modePayload(speakerLabels: true))
            #expect(decoded.speakerLabelsEnabled == true)
        }
    }

    @Test func decode_ownFlagWinsOverTheLegacyGlobal() throws {
        try withLegacyGlobal(true) {
            let decoded = try JSONDecoder().decode(VivaMode.self, from: modePayload(speakerLabels: false))
            #expect(decoded.speakerLabelsEnabled == false)
        }
    }

    @Test func decode_modeSavedBeforeTheMoveInheritsTheLegacyGlobal() throws {
        try withLegacyGlobal(true) {
            let decoded = try JSONDecoder().decode(VivaMode.self, from: modePayload(speakerLabels: nil))
            #expect(decoded.speakerLabelsEnabled == true)
        }

        try withLegacyGlobal(false) {
            let decoded = try JSONDecoder().decode(VivaMode.self, from: modePayload(speakerLabels: nil))
            #expect(decoded.speakerLabelsEnabled == false)
        }
    }

    @Test func encode_writesTheFlagSoTheLegacyGlobalStopsApplying() throws {
        let sut = VivaMode(
            id: UUID(),
            name: "Meetings",
            transcriptionProvider: .deepgram,
            transcriptionModel: "nova-3",
            aiModel: "",
            aiEnhanceEnabled: false,
            speakerLabelsEnabled: true
        )

        let encoded = try JSONEncoder().encode(sut)

        try withLegacyGlobal(false) {
            let decoded = try JSONDecoder().decode(VivaMode.self, from: encoded)
            #expect(decoded.speakerLabelsEnabled == true)
        }
    }

    // MARK: - Per-model availability

    @Test(arguments: [
        (provider: TranscriptionModelProvider.openAI, model: "gpt-4o-transcribe-diarize", expected: true),
        (provider: .openAI, model: "gpt-4o-transcribe", expected: false),
        (provider: .gemini, model: "gemini-3.5-transcribe", expected: true),
        (provider: .gemini, model: "gemini-3.1-pro-preview", expected: false),
        (provider: .deepgram, model: "nova-3", expected: true),
        (provider: .whisperKit, model: "large-v3", expected: true),
        (provider: .parakeet, model: "parakeet-tdt-0.6b-v2", expected: false),
        (provider: .groq, model: "whisper-large-v3", expected: false)
    ])
    func providerCapability(provider: TranscriptionModelProvider, model: String, expected: Bool) {
        struct StubModel: TranscriptionModel {
            let id = UUID()
            let name: String
            let displayName = ""
            let description = ""
            let provider: TranscriptionModelProvider
            let recommended = false
            let supportManyLanguages = true
            let supportedLanguages: [String: String] = [:]
        }

        let sut = StubModel(name: model, provider: provider)

        #expect(sut.supportsSpeakerDiarization == expected)
    }
}
