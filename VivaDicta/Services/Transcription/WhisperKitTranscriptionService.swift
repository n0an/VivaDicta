//
//  WhisperKitTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import Foundation
import WhisperKit
import os

/// Service responsible for transcribing audio using WhisperKit models.
/// Note: This service only loads and uses already-downloaded models.
/// Model downloading is handled by ModelDownloadManager.
@Observable
class WhisperKitTranscriptionService: TranscriptionService {
    private var whisperKit: WhisperKit?
    private var currentModelName: String?
    private var modelState: ModelState = .unloaded
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "WhisperKitTranscriptionService")

    init() {}
    
    // Separate method for loading model without progress callback for backward compatibility
    private func loadModel(modelPath: String) async throws {
        // If the same model is already loaded, return early
        if currentModelName == modelPath && modelState == .loaded {
            logger.notice("Model \(modelPath) already loaded, skipping reload")
            return
        }

        // If a different model is loaded, unload it first
        if currentModelName != modelPath && whisperKit != nil {
            logger.notice("Unloading previous model: \(self.currentModelName ?? "unknown")")
            await whisperKit?.unloadModels()
            whisperKit = nil
            modelState = .unloaded
        }

        do {
            logger.notice("🚀 Starting WhisperKit initialization for model: \(modelPath)")

            // Initialize WhisperKit without auto-loading
            let config = WhisperKitConfig(
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: false,
                download: false
            )

            whisperKit = try await WhisperKit(config)

            guard let whisperKit = whisperKit else {
                throw TranscriptionError.modelLoadFailed
            }

            // Set model folder using consolidated path from WhisperKitModel
            let modelFolder = WhisperKitModel.modelPath(for: modelPath)

            // Check if model exists locally
            if !FileManager.default.fileExists(atPath: modelFolder.path) {
                logger.error("❌ Model not found at path: \(modelFolder.path)")
                logger.error("Please download the model first using ModelDownloadManager")
                throw TranscriptionError.modelNotDownloaded
            }

            whisperKit.modelFolder = modelFolder
            modelState = .downloaded

            // Prewarm models (THIS IS THE KEY STEP!)
            logger.notice("🔥 Prewarming model: \(modelPath)")
            modelState = .prewarming

            try await whisperKit.prewarmModels()

            modelState = .prewarmed
            logger.notice("✅ Model prewarmed successfully")

            // Load models
            logger.notice("📚 Loading model: \(modelPath)")
            modelState = .loading

            try await whisperKit.loadModels()

            modelState = .loaded
            currentModelName = modelPath

            logger.notice("✅ WhisperKit model loaded and ready: \(modelPath)")

        } catch {
            modelState = .unloaded
            whisperKit = nil
            currentModelName = nil
            logger.error("❌ Failed to load WhisperKit model: \(error.localizedDescription)")
            throw error
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let whisperKitModel = model as? WhisperKitModel else {
            throw TranscriptionError.unsupportedModel
        }

        // Load model if not already loaded or if different model requested
        if whisperKit == nil || currentModelName != whisperKitModel.whisperKitModelName || modelState != .loaded {
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

            // NOTE: We NO LONGER clean up models after transcription
            // Models stay loaded in memory for faster subsequent transcriptions
            logger.notice("✅ WhisperKit transcription completed, model kept in memory for faster future use")

            return transcribedText
        } catch {
            logger.error("❌ WhisperKit transcription failed: \(error.localizedDescription)")
            throw TranscriptionError.transcriptionFailed
        }
    }

    // Add method to explicitly unload model when needed
    func unloadModel() async {
        if whisperKit != nil {
            logger.notice("🧹 Manually unloading WhisperKit model")
            await whisperKit?.unloadModels()
            whisperKit = nil
            currentModelName = nil
            modelState = .unloaded
        }
    }

    // Get current model state for UI updates
    var currentModelState: ModelState {
        return modelState
    }
}
