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
    var transcriptionModel: String = ""
    var transcriptionLanguage: String = "auto"
    var aiEnhanceEnabled: Bool = false
    var aiProvider: AIProvider?
    var aiModel: String?
    var selectedPromptID: UUID?
    
    private let transcriptionManager: TranscriptionManager
    private let aiService: AIService
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

            // Set the selected prompt ID directly from the mode
            selectedPromptID = existingMode.promptID
        } else {
            transcriptionProvider = .local
            transcriptionModel = ""
            transcriptionLanguage = "auto"
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
    
    func updateTranscriptionProvider(_ newProvider: TranscriptionModelProvider) {
        let availableModels = getAvailableTranscriptionModels(for: newProvider)
        transcriptionModel = availableModels.first ?? ""
        logger.info("Updated transcription provider to: \(newProvider.rawValue), model: \(self.transcriptionModel)")
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return aiService.connectedProviders.contains(provider)
    }
    
    // Check if transcription provider has configuration (models or API key)
    func isTranscriptionProviderConfigured(_ provider: TranscriptionModelProvider) -> Bool {
        switch provider {
        case .local:
            return !transcriptionManager.availableWhisperLocalModels.isEmpty
        case .openAI, .groq, .elevenLabs, .deepgram, .gemini:
            // Cloud providers are configured if API key exists
            let apiKey = UserDefaults.standard.string(forKey: Constants.kAPIKeyTemplate + provider.rawValue)
            return apiKey != nil && !apiKey!.isEmpty
        case .parakeet:
            // TODO: - Add Parakeet
            return false
        }
    }
    
    func getAvailableTranscriptionModels(for provider: TranscriptionModelProvider) -> [String] {
        switch provider {
        case .local:
            return transcriptionManager.availableWhisperLocalModels.compactMap { model in
                if model.name.hasPrefix("ggml-") {
                    return String(model.name.dropFirst(5))
                }
                return nil
            }
        case .openAI:
            return ["openai-gpt-4o"]
        case .groq:
            return ["whisper-large-v3-turbo"]
        case .elevenLabs:
            return ["scribe_v1"]
        case .deepgram:
            return ["nova-2"]
        case .gemini:
            return ["gemini-2.5-pro", "gemini-2.5-flash"]
        case .parakeet:
            // TODO: Add Parakeet
            return []
        }
    }
    
    func getTranscriptionModelDisplayName(_ model: String, provider: TranscriptionModelProvider) -> String {
        switch provider {
        case .local:
            switch model {
            case "tiny": return "Tiny"
            case "tiny.en": return "Tiny (English)"
            case "base": return "Base"
            case "base.en": return "Base (English)"
            case "large-v2": return "Large v2"
            case "large-v3": return "Large v3"
            case "large-v3-turbo": return "Large v3 Turbo"
            case "large-v3-turbo-q5_0": return "Large v3 Turbo (Quantized)"
            default: return model
            }
        case .openAI:
            return model == "openai-gpt-4o" ? "GPT-4o" : model
        case .groq:
            return model == "whisper-large-v3-turbo" ? "Whisper Large v3 Turbo" : model
        case .elevenLabs:
            return model == "scribe_v1" ? "Scribe v1" : model
        case .deepgram:
            return model == "nova-2" ? "Nova 2" : model
        case .gemini:
            switch model {
            case "gemini-2.5-pro": return "Gemini 2.5 Pro"
            case "gemini-2.5-flash": return "Gemini 2.5 Flash"
            default: return model
            }
        case .parakeet:
            return model
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
            aiProvider: aiEnhanceEnabled ? aiProvider : nil,
            aiModel: aiModel ?? "",
            aiEnhanceEnabled: aiEnhanceEnabled
        )
    }
    
    public func isLanguageSelectionAvailable() -> Bool {
        guard isTranscriptionProviderConfigured(transcriptionProvider) else { return false }
        return ![.parakeet, .gemini].contains(transcriptionProvider)

    }
    
    public func getAvailableLanguages() -> [(key: String, value: String)] {
        guard isLanguageSelectionAvailable() else { return [] }
        
        if transcriptionProvider == .local {
            let fullModelName = "ggml-\(transcriptionModel)"
            if let model = TranscriptionModelProvider.allLocalModels.first(where: { $0.name == fullModelName }) {
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

    private func getPromptForSelection(_ promptID: UUID?) -> String {
        guard let promptID = promptID,
              let selectedPrompt = promptsManager.userPrompts.first(where: { $0.id == promptID }) else {
            return ""
        }
        return selectedPrompt.promptInstructions
    }
}
