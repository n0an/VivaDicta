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
            selectedPromptID = existingMode.promptID
        } else {
            transcriptionProvider = .local
            transcriptionModel = ""
            transcriptionLanguage = "auto"
        }
    }
    
    func saveMode() -> FlowMode {
        let trimmedName = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Saving mode with name: '\(trimmedName)'")

        let modeId = originalMode?.id ?? UUID()

        return FlowMode(
            id: modeId,
            name: trimmedName,
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            transcriptionLanguage: transcriptionLanguage,
            promptID: selectedPromptID,
            prompt: getPromptForSelection(selectedPromptID),
            promptName: getPromptNameForSelection(selectedPromptID),
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

        // Preheat local whisper model if switching to a Local transcription
        preheatLocalTranscriptionModelIfNeeded()
    }

    func updateTranscriptionModel(_ newModel: String) {
        transcriptionModel = newModel
        logger.info("Updated transcription model to: \(newModel)")

        // Preheat local whisper model if it's Local transcription provider
        preheatLocalTranscriptionModelIfNeeded()
    }
    
    private func preheatLocalTranscriptionModelIfNeeded() {
        guard transcriptionProvider == .local,
              !transcriptionModel.isEmpty else {
            return
        }

        if let localModel = TranscriptionModelProvider.allLocalModels.first(where: { $0.name == transcriptionModel }) {
            Task {
                try? await transcriptionManager.preheatLocalModel(localModel)
                logger.info("Preheated local model: \(localModel.name)")
            }
        }
    }
    
    // MARK: - Language Settings
    public func isLanguageSelectionAvailable() -> Bool {
        guard isTranscriptionProviderConfigured(transcriptionProvider) else { return false }
        return ![.parakeet, .gemini].contains(transcriptionProvider)

    }
    
    public func getAvailableLanguages() -> [(key: String, value: String)] {
        guard isLanguageSelectionAvailable() else { return [] }
        
        if transcriptionProvider == .local {
            if let model = TranscriptionModelProvider.allLocalModels.first(where: { $0.name == transcriptionModel }) {
                return model.supportedLanguages.sorted(by: {
                    if $0.key == "auto" { return true }
                    if $1.key == "auto" { return false }
                    return $0.value < $1.value
                })
            }
        } else {
            if let model = TranscriptionModelProvider.allCloudModels.first(where: { $0.name == transcriptionModel }) {
                return model.supportedLanguages.sorted(by: {
                    if $0.key == "auto" { return true }
                    if $1.key == "auto" { return false }
                    return $0.value < $1.value
                })
            }
        }
        
        return []
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
    private func getPromptForSelection(_ promptID: UUID?) -> String {
        guard let promptID = promptID,
              let selectedPrompt = promptsManager.userPrompts.first(where: { $0.id == promptID }) else {
            return ""
        }
        return selectedPrompt.promptInstructions
    }

    private func getPromptNameForSelection(_ promptID: UUID?) -> String? {
        guard let promptID = promptID,
              let selectedPrompt = promptsManager.userPrompts.first(where: { $0.id == promptID }) else {
            return nil
        }
        return selectedPrompt.title
    }
}
