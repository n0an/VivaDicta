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
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "ModeEditViewModel")
    
    var modeName: String = ""
    
    var transcriptionProvider: TranscriptionModelProvider = .local
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
        !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            transcriptionProvider = .local
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
        
        logger.info("Saving mode with name: '\(trimmedName)'")
        
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
        case .local:
            return !transcriptionManager.availableWhisperLocalModels.isEmpty
        case .parakeet:
            // TODO: - Add Parakeet
            return false
        default: // Cloud transcription models
            guard let mappedAIProvider = provider.mappedAIProvider else { return false }
            return self.hasAPIKey(for: mappedAIProvider)
        }
    }
    
    func getAvailableTranscriptionModels(for provider: TranscriptionModelProvider) -> [String] {
        switch provider {
        case .local:
            return transcriptionManager.availableWhisperLocalModels.compactMap { $0.name }
        case .parakeet:
            // TODO: Add Parakeet
            return []
        default: // Cloud transcription models
            return provider.cloudTranscriptionModelsNames
        }
    }
    
    func updateTranscriptionProvider(_ newProvider: TranscriptionModelProvider) {
        let availableModels = getAvailableTranscriptionModels(for: newProvider)
        transcriptionModel = availableModels.first ?? ""
        logger.info("Updated transcription provider to: \(newProvider.rawValue), model: \(self.transcriptionModel)")
    }

    func updateTranscriptionModel(_ newModel: String) {
        transcriptionModel = newModel
        logger.info("Updated transcription model to: \(newModel)")

    }
    
    // MARK: - Language Settings
    public func isLanguageSelectionAvailable() -> Bool {
        guard isTranscriptionProviderConfigured(transcriptionProvider) else { return false }
        return ![.parakeet, .gemini].contains(transcriptionProvider)

    }
    
    public func getAvailableLanguages() -> [(key: String, value: String)] {
        guard isLanguageSelectionAvailable() else { return [] }

        let models: [any TranscriptionModel] = transcriptionProvider == .local ? TranscriptionModelProvider.allLocalModels : TranscriptionModelProvider.allCloudModels

        guard let model = models.first(where: { $0.name == transcriptionModel }) else {
            return []
        }

        return sortLanguages(Array(model.supportedLanguages))
    }

    private func sortLanguages(_ languages: [(key: String, value: String)]) -> [(key: String, value: String)] {
        // Sort with "auto" first, then alphabetically by value
        return languages.sorted { lhs, rhs in
            switch (lhs.key == "auto", rhs.key == "auto") {
            case (true, false): return true
            case (false, true): return false
            default: return lhs.value < rhs.value
            }
        }
    }
    
    // MARK: - AI Enhancement settings
    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider
        aiModel = newProvider?.defaultModel
        logger.info("Updated provider to: \(newProvider?.rawValue ?? "none")")
    }
    
    func updateModel(_ newModel: String?) {
        aiModel = newModel
        logger.info("Updated model to: \(newModel ?? "none")")
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
