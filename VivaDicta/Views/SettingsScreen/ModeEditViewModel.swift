//
//  ModeEditViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI
import os

@Observable
class ModeEditViewModel {
    private let logger = Logger(category: .modeEditViewModel)
    
    var modeName: String = ""
    
    var transcriptionProvider: TranscriptionModelProvider = .whisperKit
    var transcriptionModel: String = ""
    var transcriptionLanguage: String = "auto"
    
    var aiEnhanceEnabled: Bool = false
    var aiProvider: AIProvider?
    var aiModel: String?
    var selectedPromptID: UUID?
    
    let aiService: AIService
    private let transcriptionManager: TranscriptionManager
    let promptsManager: PromptsManager
    
    private let originalMode: FlowMode?

    public var transcriptionFooterText: String {
        transcriptionManager.hasAvailableTranscriptionModels ? "" : "No transcription models available. Download a local model or add an API key for a cloud model."
    }
    
    var isEditing: Bool {
        originalMode != nil
    }
    
    var isValid: Bool {
        let hasName = !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let transcriptionReady = isTranscriptionProviderConfigured(transcriptionProvider)
                                 && !transcriptionModel.isEmpty
        let aiEnhancementReady = !aiEnhanceEnabled
                                 || (aiProvider != nil
                                     && hasAPIKey(for: aiProvider!)
                                     && aiModel != nil
                                     && !aiModel!.isEmpty)

        return hasName && transcriptionReady && aiEnhancementReady
    }

    // MARK: - Validation Messages
    var transcriptionValidationMessage: String? {
        if !isTranscriptionProviderConfigured(transcriptionProvider) {
            if transcriptionProvider == .parakeet || transcriptionProvider == .whisperKit {
                return "Download a model to continue"
            } else {
                return "Add API key to continue"
            }
        }
        if transcriptionModel.isEmpty {
            return "Select a transcription model"
        }
        return nil
    }

    var aiEnhancementValidationMessage: String? {
        guard aiEnhanceEnabled else { return nil }
        if aiProvider == nil {
            return "Select an AI provider"
        }
        if !hasAPIKey(for: aiProvider!) {
            return "Add API key to continue"
        }
        if aiModel == nil || aiModel!.isEmpty {
            return "Select an AI model"
        }
        return nil
    }
    
    init(mode: FlowMode?,
         aiService: AIService,
         promptsManager: PromptsManager,
         transcriptionManager: TranscriptionManager) {
        self.originalMode = mode
        self.aiService = aiService
        self.promptsManager = promptsManager
        self.transcriptionManager = transcriptionManager
        
        if let existingMode = mode {
            modeName = existingMode.name
            transcriptionProvider = existingMode.transcriptionProvider
            transcriptionModel = existingMode.transcriptionModel
            transcriptionLanguage = existingMode.transcriptionLanguage ?? "auto"
            aiEnhanceEnabled = existingMode.aiEnhanceEnabled
            aiProvider = existingMode.aiProvider
            aiModel = existingMode.aiModel
            selectedPromptID = existingMode.userPrompt?.id
        } else {
            transcriptionProvider = .whisperKit
            transcriptionModel = ""
            transcriptionLanguage = "auto"
        }
    }
    
    func saveMode() throws -> FlowMode  {
        let trimmedName = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let modeId = originalMode?.id ?? UUID()
        
        let otherModes = aiService.modes.filter ({ $0.id != modeId })
        if otherModes.contains(where: {$0.name.lowercased() == trimmedName.lowercased()}) {
            throw SettingsError.duplicateModeName(trimmedName)
        }
        
        logger.logInfo("Saving mode with name: '\(trimmedName)'")
        
        return FlowMode(
            id: modeId,
            name: trimmedName,
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            transcriptionLanguage: transcriptionLanguage,
            userPrompt: getSelectedUserPrompt(),
            aiProvider: aiEnhanceEnabled ? aiProvider : nil,
            aiModel: aiModel ?? "",
            aiEnhanceEnabled: aiEnhanceEnabled
        )
    }
    
    // MARK: - Transcription settings
    func isTranscriptionProviderConfigured(_ provider: TranscriptionModelProvider) -> Bool {
        switch provider {
        case .parakeet:
            return !TranscriptionModelProvider.allParakeetModels.filter { $0.isDownloaded }.isEmpty
        case .whisperKit:
            return !TranscriptionModelProvider.allWhisperKitModels.filter { $0.isDownloaded }.isEmpty
        default: // Cloud transcription models
            guard let mappedAIProvider = provider.mappedAIProvider else { return false }
            return self.hasAPIKey(for: mappedAIProvider)
        }
    }
    
    func getAvailableTranscriptionModels(for provider: TranscriptionModelProvider) -> [String] {
        switch provider {
        case .parakeet:
            return TranscriptionModelProvider.allParakeetModels.filter { $0.isDownloaded }.compactMap { $0.name }
        case .whisperKit:
            return TranscriptionModelProvider.allWhisperKitModels.filter { $0.isDownloaded }.compactMap { $0.name }
        default: // Cloud transcription models
            return provider.cloudTranscriptionModelsNames
        }
    }
    
    func updateTranscriptionProvider(_ newProvider: TranscriptionModelProvider) {
        let availableModels = getAvailableTranscriptionModels(for: newProvider)
        transcriptionModel = availableModels.first ?? ""
        logger.logInfo("Updated transcription provider to: \(newProvider.rawValue), model: \(self.transcriptionModel)")
    }

    func updateTranscriptionModel(_ newModel: String) {
        transcriptionModel = newModel
        logger.logInfo("Updated transcription model to: \(newModel)")

    }
    
    // MARK: - Language Settings
    public func isLanguageSelectionAvailable() -> Bool {
        guard isTranscriptionProviderConfigured(transcriptionProvider) else { return false }
        return ![.parakeet, .gemini].contains(transcriptionProvider)

    }
    
    public struct GroupedLanguages {
        let recommended: [(key: String, value: String)]  // Auto + user's preferred
        let other: [(key: String, value: String)]        // Rest alphabetically
    }

    public func getGroupedLanguages() -> GroupedLanguages {
        guard isLanguageSelectionAvailable() else {
            return GroupedLanguages(recommended: [], other: [])
        }

        let models: [any TranscriptionModel]
        switch transcriptionProvider {
        case .whisperKit:
            models = TranscriptionModelProvider.allWhisperKitModels
        default:
            models = TranscriptionModelProvider.allCloudModels
        }

        guard let model = models.first(where: { $0.name == transcriptionModel }) else {
            return GroupedLanguages(recommended: [], other: [])
        }

        return groupLanguages(Array(model.supportedLanguages))
    }

    private func groupLanguages(_ languages: [(key: String, value: String)]) -> GroupedLanguages {
        let userPreferredCodes = getUserPreferredLanguageCodes()

        var recommended: [(key: String, value: String)] = []

        // First, find "auto" and user's preferred languages
        if let auto = languages.first(where: { $0.key == "auto" }) {
            recommended.append(auto)
        }

        // Add user's preferred languages in order
        for code in userPreferredCodes {
            if let lang = languages.first(where: { $0.key == code }) {
                recommended.append(lang)
            }
        }

        // Full alphabetical list (excluding auto, but including user's preferred languages)
        let other = languages
            .filter { $0.key != "auto" }
            .sorted { $0.value < $1.value }

        return GroupedLanguages(recommended: recommended, other: other)
    }

    private func getUserPreferredLanguageCodes() -> [String] {
        Locale.preferredLanguages.compactMap { identifier in
            // Extract language code from identifiers like "en-US", "ru-RU", "zh-Hans-CN"
            let locale = Locale(identifier: identifier)
            return locale.language.languageCode?.identifier
        }
    }
    
    // MARK: - AI Enhancement settings
    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider
        aiModel = newProvider?.defaultModel
        logger.logInfo("Updated provider to: \(newProvider?.rawValue ?? "none")")
    }

    func updateModel(_ newModel: String?) {
        aiModel = newModel
        logger.logInfo("Updated model to: \(newModel ?? "none")")
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return aiService.connectedProviders.contains(provider)
    }
    
    // MARK: - Prompt Settings
    private func getSelectedUserPrompt() -> UserPrompt? {
        guard let promptID = selectedPromptID else {
            return nil
        }
        return promptsManager.userPrompts.first { $0.id == promptID }
    }
}
