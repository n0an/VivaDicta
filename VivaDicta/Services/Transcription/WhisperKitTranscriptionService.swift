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

    // Public properties for UI display
    public var lastPrewarmDuration: TimeInterval = 0
    public var lastLoadDuration: TimeInterval = 0
    public var lastTotalInitDuration: TimeInterval = 0

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
            let totalStartTime = Date()
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

            let prewarmStart = Date()
            try await whisperKit.prewarmModels()
            let prewarmDuration = Date().timeIntervalSince(prewarmStart)
            lastPrewarmDuration = prewarmDuration

            modelState = .prewarmed
            logger.notice("✅ Model prewarmed successfully in \(String(format: "%.2f", prewarmDuration)) seconds")

            // Load models
            logger.notice("📚 Loading model: \(modelPath)")
            modelState = .loading

            let loadStart = Date()
            try await whisperKit.loadModels()
            let loadDuration = Date().timeIntervalSince(loadStart)
            lastLoadDuration = loadDuration

            modelState = .loaded
            currentModelName = modelPath

            let totalDuration = Date().timeIntervalSince(totalStartTime)
            lastTotalInitDuration = totalDuration
            logger.notice("✅ WhisperKit model loaded and ready in \(String(format: "%.2f", loadDuration)) seconds: \(modelPath)")
            logger.notice("⏱️ Total initialization time: \(String(format: "%.2f", totalDuration)) seconds (prewarm: \(String(format: "%.2f", self.lastPrewarmDuration))s, load: \(String(format: "%.2f", loadDuration))s)")

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

    // Preload model on app startup if conditions are met
    public func preloadModelIfNeeded(modelPath: String) async {
        // Check if model is already downloaded
        let modelFolder = WhisperKitModel.modelPath(for: modelPath)
        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            logger.notice("⏭️ Skipping preload: Model \(modelPath) not downloaded")
            return
        }

        // Check if model is already loaded
        if currentModelName == modelPath && modelState == .loaded {
            logger.notice("✅ Model \(modelPath) already loaded, no preload needed")
            return
        }

        logger.notice("🚀 Preloading WhisperKit model: \(modelPath)")

        do {
            // Load model without progress callback (background operation)
            try await loadModel(modelPath: modelPath)
            logger.notice("✅ Successfully preloaded WhisperKit model: \(modelPath)")
        } catch {
            logger.error("⚠️ Failed to preload WhisperKit model: \(error.localizedDescription)")
            // Don't throw - preload failure is non-critical
        }
    }
}
