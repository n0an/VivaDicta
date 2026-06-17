//
//  VivaModeModelNormalizationTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.23
//

import Foundation
import Testing
@testable import VivaDicta
import AICore

struct VivaModeModelNormalizationTests {

    // MARK: - AI model normalization

    @Test(arguments: [
        (input: "gemini-3-pro-preview", provider: AIProvider?.some(.gemini), expected: "gemini-3.1-pro-preview"),
        (input: "gemini-3.5-flash", provider: .some(.gemini), expected: "gemini-3.5-flash"),
        (input: "gemini-3-pro-preview", provider: .some(.openAI), expected: "gemini-3-pro-preview"),
        (input: "gemini-3-pro-preview", provider: nil, expected: "gemini-3-pro-preview")
    ])
    func aiModel_normalization(input: String, provider: AIProvider?, expected: String) {
        #expect(VivaMode.normalizedModelID(input, provider: provider) == expected)
    }

    // MARK: - Transcription model normalization

    @Test(arguments: [
        (input: "gemini-3-pro-preview", provider: TranscriptionModelProvider.gemini, expected: "gemini-3.1-pro-preview"),
        (input: "gemini-3.5-flash", provider: .gemini, expected: "gemini-3.5-flash"),
        (input: "gemini-3-pro-preview", provider: .openAI, expected: "gemini-3-pro-preview")
    ])
    func transcriptionModel_normalization(
        input: String,
        provider: TranscriptionModelProvider,
        expected: String
    ) {
        #expect(VivaMode.normalizedTranscriptionModelID(input, provider: provider) == expected)
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
