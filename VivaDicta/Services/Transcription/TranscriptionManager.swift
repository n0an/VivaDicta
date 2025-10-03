
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import Foundation
import SwiftUI

@Observable
class TranscriptionManager {
    private let whisperPrompt: WhisperPrompt
    private var localTranscriptionService: LocalTranscriptionService!
    private let cloudTranscriptionService = CloudTranscriptionService()
    private let parakeetTranscriptionService = ParakeetTranscriptionService()
    private let whisperKitTranscriptionService = WhisperKitTranscriptionService()
    private(set) var currentMode: FlowMode = .defaultMode

    // Callback for when cloud models are updated
    public var onCloudModelsUpdate: (() -> Void)?
    
    var allAvailableModels: [any TranscriptionModel] =
            TranscriptionModelProvider.allLocalModels +
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels

    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
    }

    var hasAvailableTranscriptionModels: Bool {
        // Check if any local models are downloaded
        let hasLocalModels = availableWhisperLocalModels.count > 0

        let hasParakeetModels = !TranscriptionModelProvider.allParakeetModels.filter { $0.isDownloaded }.isEmpty

        let hasWhisperKitModels = !TranscriptionModelProvider.allWhisperKitModels.filter { $0.isDownloaded }.isEmpty

        // Check if any cloud models are configured (have API keys)
        let hasConfiguredCloudModels = TranscriptionModelProvider.allCloudModels.contains { model in
            model.apiKey != nil
        }

        return hasLocalModels || hasParakeetModels || hasWhisperKitModels || hasConfiguredCloudModels
    }

    var selectedLanguage: String {
        get {
            // Language setting should be shared with keyboard extension
            UserDefaultsStorage.shared.string(forKey: Constants.kSelectedLanguageKey) ?? "en"
        }
        set {
            UserDefaultsStorage.shared.set(newValue, forKey: Constants.kSelectedLanguageKey)
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

    init() {
        whisperPrompt = WhisperPrompt()
        localTranscriptionService = LocalTranscriptionService()
    }

    public func setCurrentMode(_ mode: FlowMode) {
        currentMode = mode
        applyModeLanguage(mode)
    }

    private func updateLanguage(_ language: String) {
        selectedLanguage = language
        whisperPrompt.updateTranscriptionPrompt()
    }

    private func applyModeLanguage(_ mode: FlowMode) {
        let language = mode.transcriptionLanguage ?? "auto"
        updateLanguage(language)
    }

    public func updateCloudModels() {
        allAvailableModels =
            TranscriptionModelProvider.allLocalModels +
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels
        onCloudModelsUpdate?()
    }

    public func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let provider = currentMode.transcriptionProvider
        let modelName = currentMode.transcriptionModel

        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allParakeetModels + TranscriptionModelProvider.allWhisperKitModels + TranscriptionModelProvider.allCloudModels

        return allModels.first { model in
            model.provider == provider && model.name == modelName
        }
    }

    public func transcribe(audioURL: URL) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw TranscriptionError.transcriptionFailed
        }

        let transcriptionService: any TranscriptionService
        switch model.provider {
        case .local:
            transcriptionService = localTranscriptionService
        case .parakeet:
            transcriptionService = parakeetTranscriptionService
        case .whisperKit:
            transcriptionService = whisperKitTranscriptionService
        default:
            transcriptionService = cloudTranscriptionService
        }
        let text = try await transcriptionService.transcribe(audioURL: audioURL, model: model)
        return WhisperHallucinationFilter.filter(text)
    }

    // Preload WhisperKit model on app startup if conditions are met
    public func preloadWhisperKitModelIfNeeded() async {
        // Check if current mode uses WhisperKit
        guard currentMode.transcriptionProvider == .whisperKit else {
            print("📱 Preload skipped: Current mode doesn't use WhisperKit (uses \(currentMode.transcriptionProvider))")
            return
        }

        // Check if we have a valid WhisperKit model selected
        guard let model = getCurrentTranscriptionModel(),
              let whisperKitModel = model as? WhisperKitModel else {
            print("📱 Preload skipped: No valid WhisperKit model in current mode")
            return
        }

        print("📱 Starting WhisperKit model preload for: \(whisperKitModel.whisperKitModelName)")

        // Trigger preload in background
        await whisperKitTranscriptionService.preloadModelIfNeeded(modelPath: whisperKitModel.whisperKitModelName)
    }
}
