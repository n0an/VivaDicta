
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import SwiftUI
import Foundation

@Observable
class TranscriptionManager {
    private let aiService: AIService
    private let whisperPrompt: WhisperPrompt
    private let whisperContext: WhisperContext?

    var selectedLanguage: String {
        get {
            UserDefaults.standard.string(forKey: Constants.kSelectedLanguageKey) ?? "en"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.kSelectedLanguageKey)
        }
    }

    init(aiService: AIService, whisperPrompt: WhisperPrompt, whisperContext: WhisperContext?) {
        self.aiService = aiService
        self.whisperPrompt = whisperPrompt
        self.whisperContext = whisperContext
    }

    // Get current mode's transcription model
    func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let mode = aiService.selectedMode
        let provider = mode.transcriptionProvider
        let modelName = mode.transcriptionModel

        // Find the model from available models
        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        return allModels.first { model in
            model.provider == provider && model.name == modelName
        }
    }

    // Check if language selection is available for current model
    func isLanguageSelectionAvailable() -> Bool {
        guard let model = getCurrentTranscriptionModel() else { return false }

        // Check if model requires auto-detection
        if model.provider != .local {
            // Cloud models typically auto-detect
            return false
        }

        // For local models, check if it supports multiple languages
        return model.supportManyLanguages
    }

    // Get available languages for current model
    func getAvailableLanguages() -> [String: String] {
        guard let model = getCurrentTranscriptionModel() else { return [:] }
        return model.supportedLanguages
    }

    // Check if language selection is disabled (auto-detect only)
    func isLanguageSelectionDisabled() -> Bool {
        guard let model = getCurrentTranscriptionModel() else { return true }

        // Cloud models typically auto-detect
        if model.provider != .local {
            return true
        }

        // Check if it's a multilingual model that supports selection
        return !model.supportManyLanguages
    }

    // Check if current provider is configured (has models/API keys)
    func isProviderConfigured(_ provider: TranscriptionModelProvider) -> Bool {
        switch provider {
        case .local:
            // Check if any local models are downloaded
            return TranscriptionModelProvider.allLocalModels.contains { model in
                WhisperModelDownloadManager().downloadStatus(for: model) == .downloaded
            }
        case .openAI, .groq, .elevenLabs, .deepgram, .gemini:
            // Check if API key exists
            if let mappedProvider = provider.mappedAIProvider {
                return aiService.connectedProviders.contains(mappedProvider)
            }
            return false
        case .parakeet:
            // TODO: Implement Parakeet
            return false
        }
    }

    // Get available models for a provider
    func getAvailableModels(for provider: TranscriptionModelProvider) -> [String] {
        switch provider {
        case .local:
            // Return downloaded local models
            return TranscriptionModelProvider.allLocalModels
                .filter { WhisperModelDownloadManager().downloadStatus(for: $0) == .downloaded }
                .map { $0.name }
        case .openAI, .groq, .elevenLabs, .deepgram, .gemini:
            // Return cloud models for this provider
            return TranscriptionModelProvider.allCloudModels
                .filter { $0.provider == provider }
                .map { $0.name }
        case .parakeet:
            // TODO: Implement Parakeet
            return []
        }
    }

    // Get display name for a model
    func getModelDisplayName(_ modelName: String, provider: TranscriptionModelProvider) -> String {
        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        if let model = allModels.first(where: { $0.name == modelName && $0.provider == provider }) {
            return model.displayName
        }
        return modelName
    }

    // Update language and trigger prompt update
    func updateLanguage(_ language: String) {
        selectedLanguage = language
        whisperPrompt.updateTranscriptionPrompt()
    }

    // Apply mode's language setting
    func applyModeLanguage(_ mode: FlowMode) {
        let language = mode.transcriptionLanguage ?? "auto"
        updateLanguage(language)
    }

    // Transcribe using current mode's settings
    func transcribe(audioURL: URL) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw WhisperStateError.transcriptionFailed
        }

        // Use CloudTranscriptionService which handles all providers
        let service = CloudTranscriptionService()
        return try await service.transcribe(audioURL: audioURL, model: model)
    }
}
