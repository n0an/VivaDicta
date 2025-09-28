//
//  WhisperKitTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import Foundation
import WhisperKit
import os

class WhisperKitTranscriptionService: TranscriptionService {
    private var whisperKit: WhisperKit?
    private var isModelLoaded = false
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "WhisperKitTranscriptionService")

    init() {}

    func loadModel(modelPath: String) async throws {
        if isModelLoaded {
            return
        }

        do {
            // Initialize WhisperKit with specific model
            whisperKit = try await WhisperKit(model: modelPath)
            isModelLoaded = true
            logger.notice("✅ WhisperKit model loaded successfully: \(modelPath)")
        } catch {
            isModelLoaded = false
            whisperKit = nil
            logger.error("❌ Failed to load WhisperKit model: \(error.localizedDescription)")
            throw error
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let whisperKitModel = model as? WhisperKitModel else {
            throw TranscriptionError.unsupportedModel
        }

        // Load model if not already loaded
        if whisperKit == nil || !isModelLoaded {
            try await loadModel(modelPath: whisperKitModel.whisperKitModelName)
        }

        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelLoadFailed
        }

        logger.notice("🎯 Starting WhisperKit transcription with model: \(whisperKitModel.displayName)")

        do {
            // Get selected language if not auto-detect
            let language = UserDefaults.standard.string(forKey: Constants.kSelectedLanguageKey) ?? "auto"
            let decodingOptions = DecodingOptions(language: language == "auto" ? nil : language)

            // Perform transcription
            let result = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: decodingOptions)

            // Extract text from segments
            let transcribedText = result.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean up models after transcription to minimize RAM usage
            self.whisperKit = nil
            isModelLoaded = false
            logger.notice("🧹 WhisperKit models cleaned up from memory")

            logger.notice("✅ WhisperKit transcription completed successfully")
            return transcribedText
        } catch {
            logger.error("❌ WhisperKit transcription failed: \(error.localizedDescription)")
            throw TranscriptionError.transcriptionFailed
        }
    }
}