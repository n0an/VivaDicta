
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import Foundation
import SwiftUI
import os

/// Central manager coordinating all transcription services in VivaDicta.
///
/// `TranscriptionManager` serves as the primary interface for audio-to-text transcription,
/// abstracting the complexity of multiple transcription backends (WhisperKit, Parakeet,
/// and various cloud providers) behind a unified API.
///
/// ## Overview
///
/// The manager handles:
/// - Mode-based model selection (each ``VivaMode`` specifies its transcription model)
/// - Routing transcription requests to the appropriate service
/// - Post-processing transcriptions (filtering, text formatting, replacements)
/// - WhisperKit model preloading for improved performance
///
/// ## Usage
///
/// ```swift
/// let manager = TranscriptionManager()
/// manager.setCurrentMode(selectedMode)
///
/// let transcribedText = try await manager.transcribe(audioURL: recordingURL)
/// ```
///
/// ## Thread Safety
///
/// This class is marked with `@Observable` for SwiftUI integration. All public
/// methods should be called from the main actor or properly handle concurrency.
@Observable
class TranscriptionManager {
    private let logger = Logger(category: .transcriptionManager)

    private let cloudTranscriptionService = CloudTranscriptionService()
    private let parakeetTranscriptionService = ParakeetTranscriptionService()
    private let whisperKitTranscriptionService = WhisperKitTranscriptionService()

    /// The currently active transcription mode determining which model to use.
    private(set) var currentMode: VivaMode = .defaultMode

    /// Callback invoked when cloud models are updated (e.g., API key changes).
    public var onCloudModelsUpdate: (() -> Void)?

    /// All available transcription models across all providers.
    var allAvailableModels: [any TranscriptionModel] =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels

    /// Indicates whether at least one transcription model is available for use.
    ///
    /// Returns `true` if any of the following conditions are met:
    /// - A Parakeet model is downloaded
    /// - A WhisperKit model is downloaded
    /// - A cloud provider has an API key configured
    /// - A custom transcription model is configured
    var hasAvailableTranscriptionModels: Bool {
        let hasParakeetModels = !TranscriptionModelProvider.allParakeetModels.filter { $0.isDownloaded }.isEmpty

        let hasWhisperKitModels = !TranscriptionModelProvider.allWhisperKitModels.filter { $0.isDownloaded }.isEmpty

        // Check if any cloud models are configured (have API keys)
        let hasConfiguredCloudModels = TranscriptionModelProvider.allCloudModels.contains { model in
            model.apiKey != nil
        }

        // Check if custom transcription model is configured
        let hasCustomModel = CustomTranscriptionModelManager.shared.isConfigured

        return hasParakeetModels || hasWhisperKitModels || hasConfiguredCloudModels || hasCustomModel
    }

    var selectedLanguage: String {
        get {
            // Language setting should be shared with keyboard extension
            UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "en"
        }
        set {
            UserDefaultsStorage.shared.set(newValue, forKey: AppGroupCoordinator.kSelectedLanguageKey)
        }
    }

    /// Target language for inline translation during transcription (Soniox).
    /// Empty string means no translation.
    var translationTargetLanguage: String {
        get {
            UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kTranslationTargetLanguageKey) ?? ""
        }
        set {
            UserDefaultsStorage.shared.set(newValue, forKey: AppGroupCoordinator.kTranslationTargetLanguageKey)
        }
    }

    // WhisperKit performance metrics
    var whisperKitPrewarmDuration: TimeInterval {
        whisperKitTranscriptionService.lastPrewarmDuration
    }

    var whisperKitLoadDuration: TimeInterval {
        whisperKitTranscriptionService.lastLoadDuration
    }

    var whisperKitTotalInitDuration: TimeInterval {
        whisperKitTranscriptionService.lastTotalInitDuration
    }
    
    /// Sets the current transcription mode and applies its language setting.
    ///
    /// - Parameter mode: The ``VivaMode`` to activate for transcription.
    public func setCurrentMode(_ mode: VivaMode) {
        currentMode = mode
        applyModeLanguage(mode)
    }

    private func updateLanguage(_ language: String) {
        selectedLanguage = language
    }

    private func applyModeLanguage(_ mode: VivaMode) {
        let language = mode.transcriptionLanguage ?? "auto"
        updateLanguage(language)
        translationTargetLanguage = mode.translationTargetLanguage ?? ""
    }

    /// Refreshes the list of available cloud models and notifies observers.
    ///
    /// Call this method when API keys are added or removed to update the available
    /// cloud transcription models.
    public func updateCloudModels() {
        allAvailableModels =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels
        onCloudModelsUpdate?()
    }

    /// Returns the transcription model for the current mode if it's available and usable.
    ///
    /// This method validates that the model is actually ready for use:
    /// - On-device models must be downloaded
    /// - Cloud models must have an API key configured
    /// - Custom models must be properly configured
    ///
    /// - Returns: The transcription model if available and usable, or `nil` otherwise.
    public func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let provider = currentMode.transcriptionProvider
        let modelName = currentMode.transcriptionModel

        // Check for custom model first
        if provider == .customTranscription && modelName == "custom" {
            return CustomTranscriptionModelManager.shared.configuredModel
        }

        let allModels: [any TranscriptionModel] =
        TranscriptionModelProvider.allParakeetModels +
        TranscriptionModelProvider.allWhisperKitModels +
        TranscriptionModelProvider.allCloudModels

        guard let model = allModels.first(where: { $0.provider == provider && $0.name == modelName }) else {
            return nil
        }

        // Check if the model is actually usable
        if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.isDownloaded ? parakeetModel : nil
        } else if let whisperKitModel = model as? WhisperKitModel {
            return whisperKitModel.isDownloaded ? whisperKitModel : nil
        } else if let cloudModel = model as? CloudModel {
            return cloudModel.apiKey != nil ? cloudModel : nil
        }

        return model
    }
    
    /// Transcribes audio from a file URL using the current mode's model.
    ///
    /// This method routes the transcription request to the appropriate service based on
    /// the current mode's provider, then applies post-processing including:
    /// - Output filtering (removing unwanted artifacts)
    /// - Text formatting (if enabled in settings)
    /// - Custom text replacements (if enabled in settings)
    ///
    /// - Parameter audioURL: The file URL of the audio to transcribe.
    ///
    /// - Returns: The processed transcribed text.
    ///
    /// - Throws: ``TranscriptionError/transcriptionFailed`` if no valid model is configured,
    ///   or any error thrown by the underlying transcription service.
    public func transcribe(
        audioURL: URL,
        progressHandler: TranscriptionProgressHandler? = nil
    ) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw TranscriptionError.transcriptionFailed
        }

        let startTime = Date()
        let transcriptionResult: TranscriptionServiceResult
        switch model.provider {
        case .parakeet:
            transcriptionResult = try await parakeetTranscriptionService.transcribe(
                audioURL: audioURL,
                model: model,
                progressHandler: progressHandler
            )
        case .whisperKit:
            transcriptionResult = try await whisperKitTranscriptionService.transcribe(audioURL: audioURL, model: model)
        default:
            transcriptionResult = try await cloudTranscriptionService.transcribe(audioURL: audioURL, model: model)
        }

        var result = TranscriptionOutputFilter.filter(
            transcriptionResult.text,
            language: currentMode.transcriptionLanguage
        )

        // Apply text formatting if enabled for current mode
        if currentMode.isAutoTextFormattingEnabled && transcriptionResult.isSpeakerAttributed == false {
            result = TextFormatter.format(result)
        }

        // Apply text replacements if enabled
        if UserDefaults.standard.object(forKey: UserDefaultsStorage.Keys.isReplacementsEnabled) as? Bool ?? true {
            result = ReplacementsService.applyReplacements(to: result)
        }

        AnalyticsService.track(.transcriptionCompleted(
            engine: model.provider.rawValue,
            isOnDevice: TranscriptionModelProvider.localProviders.contains(model.provider),
            durationSeconds: Date().timeIntervalSince(startTime),
            outputLength: result.count
        ))

        return result
    }

    /// Preloads the WhisperKit model if the current mode uses it.
    ///
    /// Preloading prepares the model for faster first transcription by loading weights
    /// into memory ahead of time. This is called on app startup and when switching to
    /// a mode that uses WhisperKit.
    public func preloadWhisperKitModelIfNeeded() async {
        // Check if current mode uses WhisperKit
        guard currentMode.transcriptionProvider == .whisperKit else {
            logger.logInfo("📱 Preload skipped: Current mode doesn't use WhisperKit (uses \(self.currentMode.transcriptionProvider.rawValue))")
            return
        }

        // Check if we have a valid WhisperKit model selected
        guard let model = getCurrentTranscriptionModel(),
              let whisperKitModel = model as? WhisperKitModel else {
            logger.logInfo("📱 Preload skipped: No valid WhisperKit model in current mode")
            return
        }

        logger.logInfo("📱 Starting WhisperKit model preload for: \(whisperKitModel.whisperKitModelName)")

        // Trigger preload in background
        await whisperKitTranscriptionService.preloadModelIfNeeded(modelPath: whisperKitModel.whisperKitModelName)
    }
}
