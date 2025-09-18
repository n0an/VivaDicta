
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import SwiftUI
import Foundation

@Observable
class TranscriptionManager {
    var whisperContext: WhisperContext?
    private let whisperPrompt: WhisperPrompt
    private var localTranscriptionService: LocalTranscriptionService!
    private let cloudTranscriptionService = CloudTranscriptionService()
    weak var aiService: AIService?

    var allAvailableModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels

    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
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
        self.whisperPrompt = WhisperPrompt()
        self.localTranscriptionService = LocalTranscriptionService(transcriptionManager: self)
    }

    // MARK: - Local Whisper Model Preheating
    func loadCurrentTranscriptionModel() {
        guard let currentModel = getCurrentTranscriptionModel(),
              currentModel.provider == .local,
              let localWhisperModel = currentModel as? WhisperLocalModel else {
            return
        }

        Task {
            try? await loadLocalModel(localWhisperModel)
        }
    }
    
    func handleModeChange(_ mode: FlowMode) {
        applyModeLanguage(mode)
        
        // Preheat Local Whisper Model if needed
        if mode.transcriptionProvider == .local {
            if let localModel = TranscriptionModelProvider.allLocalModels.first(where: { $0.name == mode.transcriptionModel }) {
                Task {
                    try? await loadLocalModel(localModel)
                }
            }
        }
    }
    
    func loadLocalModel(_ model: WhisperLocalModel) async throws {
        do {
            whisperContext = try await WhisperContext.createContext(path: model.fileURL.path)
        } catch {
            throw WhisperStateError.modelLoadFailed
        }
    }
    
    func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        guard let aiService = aiService else { return nil }
        let mode = aiService.selectedMode
        let provider = mode.transcriptionProvider
        let modelName = mode.transcriptionModel
        
        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        
        return allModels.first { model in
            model.provider == provider && model.name == modelName
        }
    }

    // Check if language selection is available for current model
//    func isLanguageSelectionAvailable1() -> Bool {
//        guard let model = getCurrentTranscriptionModel() else { return false }
//
//        // Check if model requires auto-detection
//        if model.provider != .local {
//            // Cloud models typically auto-detect
//            return false
//        }
//
//        // For local models, check if it supports multiple languages
//        return model.supportManyLanguages
//    }

    // Get available languages for current model
//    func getAvailableLanguages1() -> [String: String] {
//        guard let model = getCurrentTranscriptionModel() else { return [:] }
//        return model.supportedLanguages
//    }

    // Check if language selection is disabled (auto-detect only)
//    func isLanguageSelectionDisabled() -> Bool {
//        guard let model = getCurrentTranscriptionModel() else { return true }
//
//        // Cloud models typically auto-detect
//        if model.provider != .local {
//            return true
//        }
//
//        // Check if it's a multilingual model that supports selection
//        return !model.supportManyLanguages
//    }

    // Check if current provider is configured (has models/API keys)
//    func isProviderConfigured(_ provider: TranscriptionModelProvider) -> Bool {
//        switch provider {
//        case .local:
//            // Check if any local models are downloaded
//            return TranscriptionModelProvider.allLocalModels.contains { model in
//                WhisperModelDownloadManager().downloadStatus(for: model) == .downloaded
//            }
//        case .openAI, .groq, .elevenLabs, .deepgram, .gemini:
//            // Check if API key exists
//            if let mappedProvider = provider.mappedAIProvider {
//                return aiService.connectedProviders.contains(mappedProvider)
//            }
//            return false
//        case .parakeet:
//            // TODO: Implement Parakeet
//            return false
//        }
//    }

    // Get available models for a provider
//    func getAvailableModels1(for provider: TranscriptionModelProvider) -> [String] {
//        switch provider {
//        case .local:
//            // Return downloaded local models
//            return TranscriptionModelProvider.allLocalModels
//                .filter { WhisperModelDownloadManager().downloadStatus(for: $0) == .downloaded }
//                .map { $0.name }
//        case .openAI, .groq, .elevenLabs, .deepgram, .gemini:
//            // Return cloud models for this provider
//            return TranscriptionModelProvider.allCloudModels
//                .filter { $0.provider == provider }
//                .map { $0.name }
//        case .parakeet:
//            // TODO: Implement Parakeet
//            return []
//        }
//    }

    // Get display name for a model
//    func getModelDisplayName1(_ modelName: String, provider: TranscriptionModelProvider) -> String {
//        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
//        if let model = allModels.first(where: { $0.name == modelName && $0.provider == provider }) {
//            return model.displayName
//        }
//        return modelName
//    }
    
    
    private func updateLanguage(_ language: String) {
        selectedLanguage = language
        whisperPrompt.updateTranscriptionPrompt()
    }
    
    func applyModeLanguage(_ mode: FlowMode) {
        let language = mode.transcriptionLanguage ?? "auto"
        updateLanguage(language)
    }
    

    func updateCloudModels() {
        allAvailableModels = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        aiService?.refreshConnectedProviders()
    }

    // Transcribe using current mode's settings
    func transcribe(audioURL: URL) async throws -> String {
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
        
        return try await transcriptionService.transcribe(audioURL: audioURL, model: model)
    }
}
