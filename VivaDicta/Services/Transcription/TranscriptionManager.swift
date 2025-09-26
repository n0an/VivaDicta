
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
    private(set) var currentMode: FlowMode = .defaultMode

    // Callback for when cloud models are updated
    public var onCloudModelsUpdate: (() -> Void)?

    var allAvailableModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels

    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
    }

    var hasAvailableTranscriptionModels: Bool {
        // Check if any local models are downloaded
        let hasLocalModels = availableWhisperLocalModels.count > 0

        // Check if any cloud models are configured (have API keys)
        let hasConfiguredCloudModels = TranscriptionModelProvider.allCloudModels.contains { model in
            model.apiKey != nil
        }

        return hasLocalModels || hasConfiguredCloudModels
    }

    var selectedLanguage: String {
        get {
            UserDefaults.standard.string(forKey: Constants.kSelectedLanguageKey) ?? "en"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.kSelectedLanguageKey)
        }
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
        allAvailableModels = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        onCloudModelsUpdate?()
    }

    public func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let provider = currentMode.transcriptionProvider
        let modelName = currentMode.transcriptionModel

        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels

        return allModels.first { model in
            model.provider == provider && model.name == modelName
        }
    }

    public func transcribe(audioURL: URL) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw WhisperStateError.transcriptionFailed
        }

        let transcriptionService: any TranscriptionService
        switch model.provider {
        case .local:
            transcriptionService = localTranscriptionService
        default:
            transcriptionService = cloudTranscriptionService
        }
        let text = try await transcriptionService.transcribe(audioURL: audioURL, model: model)
        return WhisperHallucinationFilter.filter(text)
    }
}
