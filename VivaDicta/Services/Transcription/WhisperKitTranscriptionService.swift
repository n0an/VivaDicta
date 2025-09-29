//
//  WhisperKitTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import Foundation
import WhisperKit
import os

@Observable
class WhisperKitTranscriptionService: TranscriptionService {
    private var whisperKit: WhisperKit?
    private var currentModelName: String?
    private var modelState: ModelState = .unloaded
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "WhisperKitTranscriptionService")

    init() {}

    func loadModel(modelPath: String, progressCallback: ((Double) -> Void)? = nil) async throws {
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

            // Set model folder
            let documentsPath = URL.documentsDirectory
            let modelFolder = documentsPath
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(modelPath)

            // Check if model exists locally
            if !FileManager.default.fileExists(atPath: modelFolder.path) {
                logger.notice("📥 Model not found locally, downloading: \(modelPath)")
                modelState = .downloading
                progressCallback?(0.0)

                // Download the model with progress tracking
                // Note: We'll just log progress internally for now due to Sendable constraints
                let downloadedFolder = try await WhisperKit.download(
                    variant: modelPath,
                    from: "argmaxinc/whisperkit-coreml",
                    progressCallback: { @Sendable progress in
                        let progressValue = progress.fractionCompleted
                        print("WhisperKit download progress: \(progressValue * 100)%")
                    }
                )

                whisperKit.modelFolder = downloadedFolder
                modelState = .downloaded
                progressCallback?(0.7)
            } else {
                whisperKit.modelFolder = modelFolder
                modelState = .downloaded
                progressCallback?(0.7)
            }

            // Prewarm models (THIS IS THE KEY STEP!)
            logger.notice("🔥 Prewarming model: \(modelPath)")
            modelState = .prewarming
            progressCallback?(0.75)

            try await whisperKit.prewarmModels()

            modelState = .prewarmed
            progressCallback?(0.9)
            logger.notice("✅ Model prewarmed successfully")

            // Load models
            logger.notice("📚 Loading model: \(modelPath)")
            modelState = .loading

            try await whisperKit.loadModels()

            modelState = .loaded
            progressCallback?(1.0)
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

    // Separate method for loading model without progress callback for backward compatibility
    func loadModel(modelPath: String) async throws {
        try await loadModel(modelPath: modelPath, progressCallback: nil)
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