//
//  VivaModeModelNormalizationTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.23
//

import Foundation
import Testing
@testable import VivaDicta

struct VivaModeModelNormalizationTests {

    // MARK: - AI model normalization

    @Test func aiModel_geminiRetiredProPreview_isRewritten() {
        let normalized = VivaMode.normalizedModelID("gemini-3-pro-preview", provider: .gemini)
        #expect(normalized == "gemini-3.1-pro-preview")
    }

    @Test func aiModel_currentGeminiModel_isPassedThrough() {
        let normalized = VivaMode.normalizedModelID("gemini-3.5-flash", provider: .gemini)
        #expect(normalized == "gemini-3.5-flash")
    }

    @Test func aiModel_nonGeminiProvider_isNotRewritten() {
        let normalized = VivaMode.normalizedModelID("gemini-3-pro-preview", provider: .openAI)
        #expect(normalized == "gemini-3-pro-preview")
    }

    @Test func aiModel_nilProvider_isNotRewritten() {
        let normalized = VivaMode.normalizedModelID("gemini-3-pro-preview", provider: nil)
        #expect(normalized == "gemini-3-pro-preview")
    }

    // MARK: - Transcription model normalization

    @Test func transcriptionModel_geminiRetiredProPreview_isRewritten() {
        let normalized = VivaMode.normalizedTranscriptionModelID("gemini-3-pro-preview", provider: .gemini)
        #expect(normalized == "gemini-3.1-pro-preview")
    }

    @Test func transcriptionModel_currentGeminiModel_isPassedThrough() {
        let normalized = VivaMode.normalizedTranscriptionModelID("gemini-3.5-flash", provider: .gemini)
        #expect(normalized == "gemini-3.5-flash")
    }

    @Test func transcriptionModel_nonGeminiProvider_isNotRewritten() {
        let normalized = VivaMode.normalizedTranscriptionModelID("gemini-3-pro-preview", provider: .openAI)
        #expect(normalized == "gemini-3-pro-preview")
    }

    // MARK: - Decoder integration

    @Test func decoder_rewritesRetiredTranscriptionModelOnDecode() throws {
        let modeID = UUID()
        let payload: [String: Any] = [
            "id": modeID.uuidString,
            "name": "Legacy Gemini Mode",
            "transcriptionProvider": "gemini",
            "transcriptionModel": "gemini-3-pro-preview",
            "aiProvider": "openAI",
            "aiModel": "gpt-5",
            "aiEnhanceEnabled": true
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let decoded = try JSONDecoder().decode(VivaMode.self, from: data)

        #expect(decoded.transcriptionModel == "gemini-3.1-pro-preview")
    }

    @Test func decoder_rewritesRetiredAIModelOnDecode() throws {
        let modeID = UUID()
        let payload: [String: Any] = [
            "id": modeID.uuidString,
            "name": "Legacy Gemini AI Mode",
            "transcriptionProvider": "whisperKit",
            "transcriptionModel": "whisper-base",
            "aiProvider": "gemini",
            "aiModel": "gemini-3-pro-preview",
            "aiEnhanceEnabled": true
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let decoded = try JSONDecoder().decode(VivaMode.self, from: data)

        #expect(decoded.aiModel == "gemini-3.1-pro-preview")
    }
}
