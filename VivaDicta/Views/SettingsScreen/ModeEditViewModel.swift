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
    
    // Mode properties
    var modeName: String = ""
    var transcriptionProvider: TranscriptionModelProvider = .local
    var transcriptionModel: String = "base"
    var aiEnhanceEnabled: Bool = false
    var selectedPromptID: UUID?
    
    // AI properties
    var aiProvider: AIProvider?
    var aiModel: String?
    
    private let aiService: AIService
    let promptsManager: PromptsManager
    private let mode: AIEnhanceMode?
    
    var isEditing: Bool {
        mode != nil
    }
    
    var isValid: Bool {
        !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(mode: AIEnhanceMode?, aiService: AIService, promptsManager: PromptsManager) {
        self.mode = mode
        self.aiService = aiService
        self.promptsManager = promptsManager
        loadModeData()
    }
    
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
    
    func loadFromMode(_ mode: AIEnhanceMode) {
        self.aiProvider = mode.aiProvider
        self.aiModel = mode.aiModel.isEmpty ? mode.aiProvider?.defaultModel : mode.aiModel
    }
    
    private func loadModeData() {
        if let existingMode = mode {
            modeName = existingMode.name
            transcriptionProvider = existingMode.transcriptionProvider
            transcriptionModel = existingMode.transcriptionModel
            aiEnhanceEnabled = existingMode.aiEnhanceEnabled
            loadFromMode(existingMode)
            
            // Find prompt by matching prompt text
            if !existingMode.prompt.isEmpty {
                selectedPromptID = promptsManager.userPrompts.first { prompt in
                    prompt.promptInstructions == existingMode.prompt
                }?.id
            } else {
                selectedPromptID = nil
            }
        } else {
            modeName = ""
            transcriptionProvider = .local
            transcriptionModel = "base"
            aiEnhanceEnabled = false
            updateProvider(.openAI)
            selectedPromptID = nil
        }
    }
    
    func getCurrentProvider() -> AIProvider? {
        return aiProvider
    }
    
    func getCurrentModel() -> String {
        return aiModel ?? aiProvider?.defaultModel ?? ""
    }
    
    func saveMode() -> AIEnhanceMode {
        let trimmedName = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Saving mode with name: '\(trimmedName)'")
        
        if let existingMode = mode {
            // Preserve the ID when editing an existing mode
            return AIEnhanceMode(
                id: existingMode.id,
                name: trimmedName,
                transcriptionProvider: transcriptionProvider,
                transcriptionModel: transcriptionModel,
                prompt: getPromptForSelection(selectedPromptID),
                aiProvider: aiEnhanceEnabled ? getCurrentProvider() : nil,
                aiModel: getCurrentModel(),
                aiEnhanceEnabled: aiEnhanceEnabled
            )
        } else {
            // Create new mode with new ID
            return AIEnhanceMode(
                id: UUID(),
                name: trimmedName,
                transcriptionProvider: transcriptionProvider,
                transcriptionModel: transcriptionModel,
                prompt: getPromptForSelection(selectedPromptID),
                aiProvider: aiEnhanceEnabled ? getCurrentProvider() : nil,
                aiModel: getCurrentModel(),
                aiEnhanceEnabled: aiEnhanceEnabled
            )
        }
    }
    
    private func getPromptForSelection(_ promptID: UUID?) -> String {
        guard let promptID = promptID,
              let selectedPrompt = promptsManager.userPrompts.first(where: { $0.id == promptID }) else {
            return ""
        }
        return selectedPrompt.promptInstructions
    }
}
