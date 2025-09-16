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
    
    // Simple bindable properties
    var modeName: String = ""
    var transcriptionProvider: TranscriptionModelProvider = .local
    var transcriptionModel: String = "base"
    var aiEnhanceEnabled: Bool = false
    var aiProvider: AIProvider?
    var aiModel: String?
    var selectedPromptID: UUID?
    
    private let aiService: AIService
    let promptsManager: PromptsManager
    private let originalMode: AIEnhanceMode?
    
    var isEditing: Bool {
        originalMode != nil
    }
    
    var isValid: Bool {
        !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(mode: AIEnhanceMode?, aiService: AIService, promptsManager: PromptsManager) {
        self.originalMode = mode
        self.aiService = aiService
        self.promptsManager = promptsManager
        
        if let existingMode = mode {
            modeName = existingMode.name
            transcriptionProvider = existingMode.transcriptionProvider
            transcriptionModel = existingMode.transcriptionModel
            aiEnhanceEnabled = existingMode.aiEnhanceEnabled
            aiProvider = existingMode.aiProvider
            aiModel = existingMode.aiModel
            
            // Set the selected prompt ID directly from the mode
            selectedPromptID = existingMode.promptID
        } else {
            modeName = ""
            transcriptionProvider = .local
            transcriptionModel = "base"
            aiEnhanceEnabled = false
            aiProvider = .openAI
            aiModel = AIProvider.openAI.defaultModel
        }
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
    
    func saveMode() -> AIEnhanceMode {
        let trimmedName = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Saving mode with name: '\(trimmedName)'")
        
        let modeId = originalMode?.id ?? UUID()
        
        return AIEnhanceMode(
            id: modeId,
            name: trimmedName,
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            promptID: selectedPromptID,
            prompt: getPromptForSelection(selectedPromptID),
            aiProvider: aiEnhanceEnabled ? aiProvider : nil,
            aiModel: aiModel ?? "",
            aiEnhanceEnabled: aiEnhanceEnabled
        )
    }
    
    private func getPromptForSelection(_ promptID: UUID?) -> String {
        guard let promptID = promptID,
              let selectedPrompt = promptsManager.userPrompts.first(where: { $0.id == promptID }) else {
            return ""
        }
        return selectedPrompt.promptInstructions
    }
}
