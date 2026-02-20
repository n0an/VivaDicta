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
    
    let originalMode: VivaMode?

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

        let aiEnhancementReady: Bool
        if !aiEnhanceEnabled {
            aiEnhancementReady = true
        } else if let provider = aiProvider,
                  let model = aiModel,
                  !model.isEmpty,
                  isProviderReady(provider),
                  selectedPromptID != nil {
            aiEnhancementReady = true
        } else {
            aiEnhancementReady = false
        }

        return hasName && transcriptionReady && aiEnhancementReady
    }

    // MARK: - Validation Messages
    var transcriptionValidationMessage: String? {
        if !isTranscriptionProviderConfigured(transcriptionProvider) {
            if transcriptionProvider == .parakeet || transcriptionProvider == .whisperKit {
                return "Download a model to continue"
            } else if transcriptionProvider == .customTranscription {
                return "Configure custom model to continue"
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
        guard let provider = aiProvider else {
            return "Select an AI provider"
        }
        if !isProviderReady(provider) {
            if provider == .apple {
                return "Apple Intelligence is not available on this device"
            }
            if provider == .ollama {
                return "Configure Ollama server in AI Providers settings"
            }
            if provider == .customOpenAI {
                return "Configure Custom AI Provider in AI Providers settings"
            }
            return "Add API key to continue"
        }
        if aiModel == nil || aiModel!.isEmpty {
            return "Select an AI model"
        }
        if selectedPromptID == nil {
            return "Select or add a prompt"
        }
        return nil
    }
    
    init(mode: VivaMode?,
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

            validateLanguageSelection()
            validateAIModelSelection()
        } else {
            transcriptionProvider = .whisperKit
            transcriptionModel = ""
            transcriptionLanguage = "auto"
        }
    }
    
    func saveMode() throws -> VivaMode  {
        let trimmedName = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let modeId = originalMode?.id ?? UUID()

        let otherModes = aiService.modes.filter ({ $0.id != modeId })
        let normalizedName = normalizeForComparison(trimmedName)
        if otherModes.contains(where: { normalizeForComparison($0.name) == normalizedName }) {
            throw SettingsError.duplicateModeName(trimmedName)
        }

        logger.logInfo("Saving mode with name: '\(trimmedName)'")

        return VivaMode(
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
        case .customTranscription:
            return CustomTranscriptionModelManager.shared.isConfigured
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
        case .customTranscription:
            // Custom transcription has a single fixed model name
            return CustomTranscriptionModelManager.shared.isConfigured ? ["custom"] : []
        default: // Cloud transcription models
            return provider.cloudTranscriptionModelsNames
        }
    }
    
    func updateTranscriptionProvider(_ newProvider: TranscriptionModelProvider) {
        let availableModels = getAvailableTranscriptionModels(for: newProvider)
        transcriptionModel = availableModels.first ?? ""
        logger.logInfo("Updated transcription provider to: \(newProvider.rawValue), model: \(self.transcriptionModel)")

        validateLanguageSelection()
    }

    func updateTranscriptionModel(_ newModel: String) {
        transcriptionModel = newModel
        logger.logInfo("Updated transcription model to: \(newModel)")

        validateLanguageSelection()
    }

    private func validateLanguageSelection() {
        let grouped = getGroupedLanguages()
        let allLanguages = grouped.recommended + grouped.other

        let isCurrentLanguageValid = allLanguages.contains { $0.key == transcriptionLanguage }

        if !isCurrentLanguageValid, let firstLanguage = allLanguages.first {
            let oldLanguage = transcriptionLanguage
            transcriptionLanguage = firstLanguage.key
            logger.logInfo("Language '\(oldLanguage)' not supported by model, reset to '\(firstLanguage.key)'")
        }
    }

    private func validateAIModelSelection() {
        guard let provider = aiProvider else { return }

        if provider == .ollama {
            let availableModels = aiService.ollamaModels
            guard let currentModel = aiModel else { return }

            if !availableModels.contains(currentModel) {
                let oldModel = currentModel
                if let firstModel = availableModels.first {
                    aiModel = firstModel
                    logger.logInfo("Ollama model '\(oldModel)' not available, reset to '\(firstModel)'")
                } else {
                    aiModel = nil
                    logger.logInfo("Ollama model '\(oldModel)' not available and no models found")
                }
            }
        } else if provider == .customOpenAI {
            // For Custom OpenAI, validate model matches configured model
            let configuredModel = aiService.customOpenAIModelName
            if configuredModel.isEmpty {
                aiModel = nil
                logger.logInfo("Custom OpenAI model not configured")
            } else if aiModel != configuredModel {
                aiModel = configuredModel
                logger.logInfo("Custom OpenAI model updated to configured: '\(configuredModel)'")
            }
        }
    }

    // MARK: - Language Settings
    public func isLanguageSelectionAvailable() -> Bool {
        guard isTranscriptionProviderConfigured(transcriptionProvider) else { return false }

        if transcriptionProvider == .gemini { return false }

        if transcriptionProvider == .parakeet { return transcriptionModel == "parakeet-tdt-0.6b-v2" }

        // Custom transcription - only show language picker if multilingual
        if transcriptionProvider == .customTranscription {
            return CustomTranscriptionModelManager.shared.customModel.isMultilingual
        }

        return true

    }
    
    public struct GroupedLanguages {
        let recommended: [(key: String, value: String)]  // Auto + user's preferred
        let other: [(key: String, value: String)]        // Rest alphabetically
    }

    public func getGroupedLanguages() -> GroupedLanguages {
        guard isLanguageSelectionAvailable() else {
            return GroupedLanguages(recommended: [], other: [])
        }

        // Custom transcription - use all languages if multilingual
        if transcriptionProvider == .customTranscription {
            return groupLanguages(Array(TranscriptionModelProvider.allLanguages))
        }

        let models: [any TranscriptionModel]
        switch transcriptionProvider {
        case .whisperKit:
            models = TranscriptionModelProvider.allWhisperKitModels
        case .parakeet:
            models = TranscriptionModelProvider.allParakeetModels
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
    func selectFirstProviderIfNeeded() {
        guard aiProvider == nil else { return }

        // First try Apple if available (on-device is preferred)
        if aiService.connectedProviders.contains(.apple) {
            aiProvider = .apple
            aiModel = AIProvider.apple.defaultModel
            logger.logInfo("Auto-selected Apple Foundation Model (on-device)")
            return
        }

        // Then try to find a cloud provider with API key configured
        let firstConnectedProvider = AIProvider.cloudProviders.first { provider in
            aiService.connectedProviders.contains(provider)
        }

        // If no connected provider, just select the first cloud provider (so UI shows "Add API Key")
        let providerToSelect = firstConnectedProvider ?? AIProvider.cloudProviders.first

        if let provider = providerToSelect {
            aiProvider = provider

            // For Ollama, select first available model if default isn't available
            if provider == .ollama {
                let availableModels = aiService.ollamaModels
                if availableModels.contains(provider.defaultModel) {
                    aiModel = provider.defaultModel
                } else if let firstModel = availableModels.first {
                    aiModel = firstModel
                } else {
                    aiModel = nil // No models available
                }
            } else {
                aiModel = provider.defaultModel
            }

            logger.logInfo("Auto-selected provider: \(provider.rawValue)")
        }
    }

    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider

        // For Ollama, select first available model if default isn't available
        if let provider = newProvider, provider == .ollama {
            let availableModels = aiService.ollamaModels
            if availableModels.contains(provider.defaultModel) {
                aiModel = provider.defaultModel
            } else if let firstModel = availableModels.first {
                aiModel = firstModel
            } else {
                aiModel = nil // No models available
            }

            // Verify Ollama connection when selected
            verifyOllamaConnection()
        } else if let provider = newProvider, provider == .customOpenAI {
            // For Custom OpenAI, use the configured model name
            let modelName = aiService.customOpenAIModelName
            aiModel = modelName.isEmpty ? nil : modelName

            // Verify Custom OpenAI connection when selected
            verifyCustomOpenAIConnection()
        } else {
            aiModel = newProvider?.defaultModel
        }

        logger.logInfo("Updated provider to: \(newProvider?.rawValue ?? "none"), model: \(aiModel ?? "none")")
    }

    /// Verifies Ollama connection when user selects it as provider
    private func verifyOllamaConnection() {
        Task {
            let result = await aiService.verifyOllamaSetup()
            await MainActor.run {
                if result.success {
                    logger.logInfo("Ollama connection verified: \(result.message)")
                    // Update model selection with fresh models list
                    if let firstModel = aiService.ollamaModels.first {
                        if aiModel == nil || !aiService.ollamaModels.contains(aiModel!) {
                            aiModel = firstModel
                        }
                    }
                } else {
                    logger.logWarning("Ollama connection failed: \(result.message)")
                    // Clear models and disable for all modes
                    aiService.ollamaModels = []
                    aiService.disableOllamaEnhancementForAllModes()
                    aiModel = nil
                }
                aiService.refreshConnectedProviders()
            }
        }
    }

    /// Verifies Custom OpenAI connection when user selects it as provider
    private func verifyCustomOpenAIConnection() {
        // Only verify if configuration exists
        guard !aiService.customOpenAIEndpointURL.isEmpty,
              !aiService.customOpenAIModelName.isEmpty else {
            return
        }

        Task {
            let result = await aiService.verifyCustomOpenAISetup()
            await MainActor.run {
                if result.success {
                    aiService.customOpenAIIsVerified = true
                    logger.logInfo("Custom OpenAI connection verified: \(result.message)")
                } else {
                    aiService.customOpenAIIsVerified = false
                    aiService.disableCustomOpenAIEnhancementForAllModes()
                    logger.logWarning("Custom OpenAI connection failed: \(result.message)")
                }
                aiService.refreshConnectedProviders()
            }
        }
    }

    func updateModel(_ newModel: String?) {
        aiModel = newModel
        logger.logInfo("Updated model to: \(newModel ?? "none")")
    }

    /// Refreshes the AI model selection based on current provider state
    /// Called when returning from configuration screens to sync with any changes
    func refreshAIModelSelection() {
        guard let provider = aiProvider else { return }

        if provider == .ollama {
            let availableModels = aiService.ollamaModels
            if let currentModel = aiModel, availableModels.contains(currentModel) {
                // Current model is still valid, keep it
                return
            }
            // Select first available model
            if let firstModel = availableModels.first {
                aiModel = firstModel
                logger.logInfo("Refreshed Ollama model to: \(firstModel)")
            } else {
                aiModel = nil
            }
        } else if provider == .customOpenAI {
            let configuredModel = aiService.customOpenAIModelName
            if !configuredModel.isEmpty && aiModel != configuredModel {
                aiModel = configuredModel
                logger.logInfo("Refreshed Custom OpenAI model to: \(configuredModel)")
            } else if configuredModel.isEmpty {
                aiModel = nil
            }
        }
    }
    
    func refreshConnectedProviders() {
        aiService.refreshConnectedProviders()
    }

    func hasAPIKey(for provider: AIProvider) -> Bool {
        // Apple doesn't need API key - just check if it's available
        if provider == .apple {
            return aiService.connectedProviders.contains(.apple)
        }
        return aiService.connectedProviders.contains(provider)
    }

    /// Returns whether the provider is ready to use
    /// For Apple: available on device
    /// For Ollama: has models available (server configured and accessible)
    /// For Custom OpenAI: endpoint URL and model name are configured
    /// For cloud providers: API key is configured
    func isProviderReady(_ provider: AIProvider) -> Bool {
        if provider == .ollama {
            // Ollama is ready only if models are available
            return !aiService.ollamaModels.isEmpty
        }
        if provider == .customOpenAI {
            // Custom OpenAI is ready only if URL and model are configured AND verified
            return !aiService.customOpenAIEndpointURL.isEmpty &&
                   !aiService.customOpenAIModelName.isEmpty &&
                   aiService.customOpenAIIsVerified
        }
        return aiService.connectedProviders.contains(provider)
    }

    /// Check if Apple Foundation Model is available on this device
    @MainActor
    var isAppleFoundationModelAvailable: Bool {
        AppleFoundationModelAvailability.isAvailable
    }

    /// Get availability status message for Apple Foundation Model
    @MainActor
    var appleFoundationModelStatusMessage: String {
        AppleFoundationModelAvailability.currentStatus.description
    }
    
    // MARK: - Prompt Settings
    func selectFirstPromptIfNeeded() {
        if selectedPromptID == nil, let firstPrompt = promptsManager.userPrompts.first {
            selectedPromptID = firstPrompt.id
            logger.logInfo("Auto-selected first prompt: \(firstPrompt.title)")
        }
    }

    private func getSelectedUserPrompt() -> UserPrompt? {
        guard let promptID = selectedPromptID else {
            return nil
        }
        return promptsManager.userPrompts.first { $0.id == promptID }
    }

    /// Normalizes a name for comparison by removing all whitespace and lowercasing
    private func normalizeForComparison(_ name: String) -> String {
        name.split(separator: /\s+/).joined().lowercased()
    }
}
