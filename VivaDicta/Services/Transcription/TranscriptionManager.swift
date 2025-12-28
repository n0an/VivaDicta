
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import Foundation
import SwiftUI
import os

@Observable
class TranscriptionManager {
    private let logger = Logger(category: .transcriptionManager)
    
    private let cloudTranscriptionService = CloudTranscriptionService()
    private let parakeetTranscriptionService = ParakeetTranscriptionService()
    private let whisperKitTranscriptionService = WhisperKitTranscriptionService()
    private(set) var currentMode: VivaMode = .defaultMode

    // Callback for when cloud models are updated
    public var onCloudModelsUpdate: (() -> Void)?
    
    var allAvailableModels: [any TranscriptionModel] =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels
    
    var hasAvailableTranscriptionModels: Bool {
        let hasParakeetModels = !TranscriptionModelProvider.allParakeetModels.filter { $0.isDownloaded }.isEmpty

        let hasWhisperKitModels = !TranscriptionModelProvider.allWhisperKitModels.filter { $0.isDownloaded }.isEmpty

        // Check if any cloud models are configured (have API keys)
        let hasConfiguredCloudModels = TranscriptionModelProvider.allCloudModels.contains { model in
            model.apiKey != nil
        }

        return hasParakeetModels || hasWhisperKitModels || hasConfiguredCloudModels
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
    }

    public func updateCloudModels() {
        allAvailableModels =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels
        onCloudModelsUpdate?()
    }

    public func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let provider = currentMode.transcriptionProvider
        let modelName = currentMode.transcriptionModel

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
    

    public func transcribe(audioURL: URL) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw TranscriptionError.transcriptionFailed
        }

        let transcriptionService: any TranscriptionService
        switch model.provider {
        case .parakeet:
            transcriptionService = parakeetTranscriptionService
        case .whisperKit:
            transcriptionService = whisperKitTranscriptionService
        default:
            transcriptionService = cloudTranscriptionService
        }
        let text = try await transcriptionService.transcribe(audioURL: audioURL, model: model)
        
        var result = TranscriptionOutputFilter.filter(text)
        
        // Aply text formatting if enabled
        if UserDefaults.standard.object(forKey: UserDefaultsStorage.Keys.isTextFormattingEnabled) as? Bool ?? true {
            result = TextFormatter.format(result)
        }

        // Apply text replacements if enabled
        if UserDefaults.standard.object(forKey: UserDefaultsStorage.Keys.isReplacementsEnabled) as? Bool ?? true {
            result = ReplacementsService.applyReplacements(to: result)
        }

        return result
    }

    // Preload WhisperKit model on app startup if conditions are met
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
