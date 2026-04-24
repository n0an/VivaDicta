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
    var usesSeparateReminderExtractor: Bool = false
    var reminderExtractorProvider: AIProvider?
    var reminderExtractorModel: String?
    var selectedPresetId: String?
    var useClipboardContext: Bool = false
    var isAutoTextFormattingEnabled: Bool = false
    var isSmartInsertEnabled: Bool = false

    var obsidianEnabled: Bool = false
    var obsidianVault: String = ""
    var obsidianNoteTemplate: String = "{date}"
    var obsidianLinePrefix: String = "- {time} "

    let aiService: AIService
    private let transcriptionManager: TranscriptionManager
    let presetManager: PresetManager

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
                  selectedPresetId != nil {
            aiEnhancementReady = true
        } else {
            aiEnhancementReady = false
        }

        let reminderExtractorReady: Bool
        if !aiEnhanceEnabled || !usesSeparateReminderExtractor {
            reminderExtractorReady = true
        } else if let provider = reminderExtractorProvider,
                  let model = reminderExtractorModel,
                  !model.isEmpty,
                  isProviderReady(provider) {
            reminderExtractorReady = true
        } else {
            reminderExtractorReady = false
        }

        return hasName && transcriptionReady && aiEnhancementReady && reminderExtractorReady
    }

    var hasNameError: Bool {
        modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasTranscriptionError: Bool {
        transcriptionValidationMessage != nil
    }

    var hasAIProcessingError: Bool {
        aiEnhancementValidationMessage != nil
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

    private static let disableHint = ", or disable AI Processing"
    private static let disableReminderExtractorHint = ", or turn off the separate extractor"

    var aiEnhancementValidationMessage: String? {
        guard aiEnhanceEnabled else { return nil }
        guard let provider = aiProvider else {
            return "Select an AI provider\(Self.disableHint)"
        }
        if !isProviderReady(provider) {
            if provider == .apple {
                return "\(appleFoundationModelStatusMessage)\(Self.disableHint)"
            }
            if provider == .ollama {
                return "Configure Ollama server in AI Providers settings\(Self.disableHint)"
            }
            if provider == .customOpenAI {
                return "Configure Custom AI Provider in AI Providers settings\(Self.disableHint)"
            }
            return "Add API key to continue\(Self.disableHint)"
        }
        if aiModel == nil || aiModel!.isEmpty {
            return "Select an AI model\(Self.disableHint)"
        }
        if selectedPresetId == nil {
            return "Select a preset\(Self.disableHint)"
        }
        return nil
    }

    var hasReminderExtractorError: Bool {
        reminderExtractorValidationMessage != nil
    }

    var reminderExtractorValidationMessage: String? {
        guard aiEnhanceEnabled, usesSeparateReminderExtractor else { return nil }
        guard let provider = reminderExtractorProvider else {
            return "Select a reminder extractor provider\(Self.disableReminderExtractorHint)"
        }
        if !isProviderReady(provider) {
            if provider == .apple {
                return "\(appleFoundationModelStatusMessage)\(Self.disableReminderExtractorHint)"
            }
            if provider == .ollama {
                return "Configure Ollama server in AI Providers settings\(Self.disableReminderExtractorHint)"
            }
            if provider == .customOpenAI {
                return "Configure Custom AI Provider in AI Providers settings\(Self.disableReminderExtractorHint)"
            }
            return "Add API key to continue\(Self.disableReminderExtractorHint)"
        }
        if reminderExtractorModel == nil || reminderExtractorModel?.isEmpty == true {
            return "Select a reminder extractor model\(Self.disableReminderExtractorHint)"
        }
        return nil
    }

    init(mode: VivaMode?,
         aiService: AIService,
         presetManager: PresetManager,
         transcriptionManager: TranscriptionManager) {
        self.originalMode = mode
        self.aiService = aiService
        self.presetManager = presetManager
        self.transcriptionManager = transcriptionManager

        if let existingMode = mode {
            modeName = existingMode.name
            transcriptionProvider = existingMode.transcriptionProvider
            transcriptionModel = existingMode.transcriptionModel
            transcriptionLanguage = existingMode.transcriptionLanguage ?? "auto"
            aiEnhanceEnabled = existingMode.aiEnhanceEnabled
            aiProvider = existingMode.aiProvider
            aiModel = existingMode.aiModel
            usesSeparateReminderExtractor = existingMode.reminderExtractorProvider != nil
            reminderExtractorProvider = existingMode.reminderExtractorProvider
            reminderExtractorModel = existingMode.reminderExtractorModel
            selectedPresetId = existingMode.presetId
            useClipboardContext = existingMode.useClipboardContext
            isAutoTextFormattingEnabled = existingMode.isAutoTextFormattingEnabled
            isSmartInsertEnabled = existingMode.isSmartInsertEnabled
            obsidianEnabled = existingMode.obsidianEnabled
            obsidianVault = existingMode.obsidianVault
            obsidianNoteTemplate = existingMode.obsidianNoteTemplate
            obsidianLinePrefix = existingMode.obsidianLinePrefix

            validateLanguageSelection()
            validateAIModelSelection()
            validateReminderExtractorModelSelection()
            if !aiEnhanceEnabled {
                setSeparateReminderExtractorEnabled(false)
            }
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
            presetId: aiEnhanceEnabled ? selectedPresetId : nil,
            aiProvider: aiEnhanceEnabled ? aiProvider : nil,
            aiModel: aiModel ?? "",
            reminderExtractorProvider: aiEnhanceEnabled && usesSeparateReminderExtractor ? reminderExtractorProvider : nil,
            reminderExtractorModel: aiEnhanceEnabled && usesSeparateReminderExtractor ? reminderExtractorModel : nil,
            aiEnhanceEnabled: aiEnhanceEnabled,
            useClipboardContext: aiEnhanceEnabled ? useClipboardContext : false,
            isAutoTextFormattingEnabled: isAutoTextFormattingEnabled,
            isSmartInsertEnabled: isSmartInsertEnabled,
            obsidianEnabled: obsidianEnabled,
            obsidianVault: obsidianVault.trimmingCharacters(in: .whitespacesAndNewlines),
            obsidianNoteTemplate: obsidianNoteTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            obsidianLinePrefix: obsidianLinePrefix
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
        default: // Cloud transcription models require an actual API key (OAuth/CLI won't work)
            guard let mappedAIProvider = provider.mappedAIProvider else { return false }
            return mappedAIProvider.apiKey != nil
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

    private func validateReminderExtractorModelSelection() {
        guard let provider = reminderExtractorProvider else { return }

        if provider == .ollama {
            let availableModels = aiService.ollamaModels
            guard let currentModel = reminderExtractorModel else { return }

            if !availableModels.contains(currentModel) {
                let oldModel = currentModel
                if let firstModel = availableModels.first {
                    reminderExtractorModel = firstModel
                    logger.logInfo("Reminder extractor Ollama model '\(oldModel)' not available, reset to '\(firstModel)'")
                } else {
                    reminderExtractorModel = nil
                    logger.logInfo("Reminder extractor Ollama model '\(oldModel)' not available and no models found")
                }
            }
        } else if provider == .customOpenAI {
            let configuredModel = aiService.customOpenAIModelName
            if configuredModel.isEmpty {
                reminderExtractorModel = nil
                logger.logInfo("Reminder extractor Custom OpenAI model not configured")
            } else if reminderExtractorModel != configuredModel {
                reminderExtractorModel = configuredModel
                logger.logInfo("Reminder extractor Custom OpenAI model updated to configured: '\(configuredModel)'")
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

    // MARK: - AI Processing settings
    private enum ModelSelectionTarget {
        case aiEnhancement
        case reminderExtraction

        var logName: String {
            switch self {
            case .aiEnhancement:
                "AI"
            case .reminderExtraction:
                "reminder extractor"
            }
        }
    }

    func selectFirstProviderIfNeeded() {
        guard aiProvider == nil else { return }

        if let provider = preferredProviderForSelection() {
            aiProvider = provider
            aiModel = defaultModel(for: provider)
            logger.logInfo("Auto-selected provider: \(provider.rawValue)")
        }
    }

    func selectFirstReminderExtractorProviderIfNeeded() {
        guard reminderExtractorProvider == nil else { return }

        if let provider = preferredProviderForSelection() {
            reminderExtractorProvider = provider
            reminderExtractorModel = defaultModel(for: provider)
            logger.logInfo("Auto-selected reminder extractor provider: \(provider.rawValue)")
        }
    }

    func setAIEnhancementEnabled(_ isEnabled: Bool) {
        aiEnhanceEnabled = isEnabled

        if !isEnabled {
            setSeparateReminderExtractorEnabled(false)
        }
    }

    func setSeparateReminderExtractorEnabled(_ isEnabled: Bool) {
        usesSeparateReminderExtractor = isEnabled

        if !isEnabled {
            reminderExtractorProvider = nil
            reminderExtractorModel = nil
            logger.logInfo("Disabled separate reminder extractor")
            return
        }

        if reminderExtractorProvider == nil {
            if let provider = aiProvider,
               isProviderReady(provider),
               let model = aiModel,
               !model.isEmpty {
                reminderExtractorProvider = provider
                reminderExtractorModel = model
                logger.logInfo("Prefilled separate reminder extractor from AI processing provider: \(provider.rawValue)")
            } else {
                selectFirstReminderExtractorProviderIfNeeded()
            }
        }
    }

    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider
        aiModel = defaultModel(for: newProvider)
        triggerProviderVerificationIfNeeded(for: newProvider, target: .aiEnhancement)
        logger.logInfo("Updated provider to: \(newProvider?.rawValue ?? "none"), model: \(aiModel ?? "none")")
    }

    func updateReminderExtractorProvider(_ newProvider: AIProvider?) {
        reminderExtractorProvider = newProvider
        reminderExtractorModel = defaultModel(for: newProvider)
        triggerProviderVerificationIfNeeded(for: newProvider, target: .reminderExtraction)
        logger.logInfo("Updated reminder extractor provider to: \(newProvider?.rawValue ?? "none"), model: \(reminderExtractorModel ?? "none")")
    }

    func updateModel(_ newModel: String?) {
        aiModel = newModel
        logger.logInfo("Updated model to: \(newModel ?? "none")")
    }

    func updateReminderExtractorModel(_ newModel: String?) {
        reminderExtractorModel = newModel
        logger.logInfo("Updated reminder extractor model to: \(newModel ?? "none")")
    }

    /// Refreshes the AI model selection based on current provider state
    /// Called when returning from configuration screens to sync with any changes
    func refreshAIModelSelection() {
        guard let provider = aiProvider else { return }
        refreshModelSelection(for: provider, target: .aiEnhancement)
    }

    func refreshReminderExtractorModelSelection() {
        guard let provider = reminderExtractorProvider else { return }
        refreshModelSelection(for: provider, target: .reminderExtraction)
    }

    private func preferredProviderForSelection() -> AIProvider? {
        if aiService.connectedProviders.contains(.apple) {
            return .apple
        }

        let firstConnectedProvider = AIProvider.cloudProviders.first { provider in
            aiService.connectedProviders.contains(provider)
        }

        return firstConnectedProvider ?? AIProvider.cloudProviders.first
    }

    private func defaultModel(for provider: AIProvider?) -> String? {
        guard let provider else { return nil }

        if provider == .ollama {
            let availableModels = aiService.ollamaModels
            if availableModels.contains(provider.defaultModel) {
                return provider.defaultModel
            }
            return availableModels.first
        }

        if provider == .customOpenAI {
            let modelName = aiService.customOpenAIModelName
            return modelName.isEmpty ? nil : modelName
        }

        return provider.defaultModel
    }

    private func triggerProviderVerificationIfNeeded(
        for provider: AIProvider?,
        target: ModelSelectionTarget
    ) {
        guard let provider else { return }

        if provider == .ollama {
            verifyOllamaConnection(for: target)
        } else if provider == .customOpenAI {
            verifyCustomOpenAIConnection(for: target)
        }
    }

    private func verifyOllamaConnection(for target: ModelSelectionTarget) {
        Task {
            let result = await aiService.verifyOllamaSetup()
            await MainActor.run {
                if result.success {
                    logger.logInfo("Ollama connection verified: \(result.message)")
                    if let firstModel = aiService.ollamaModels.first {
                        if let currentModel = currentModel(for: target),
                           aiService.ollamaModels.contains(currentModel) {
                            return
                        }
                        setModel(firstModel, for: target)
                    }
                } else {
                    logger.logWarning("Ollama connection failed: \(result.message)")
                    aiService.ollamaModels = []
                    aiService.disableOllamaEnhancementForAllModes()
                    setModel(nil, for: target)
                }
                aiService.refreshConnectedProviders()
            }
        }
    }

    private func verifyCustomOpenAIConnection(for target: ModelSelectionTarget) {
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
                    let configuredModel = aiService.customOpenAIModelName
                    if !configuredModel.isEmpty {
                        setModel(configuredModel, for: target)
                    }
                } else {
                    aiService.customOpenAIIsVerified = false
                    aiService.disableCustomOpenAIEnhancementForAllModes()
                    logger.logWarning("Custom OpenAI connection failed: \(result.message)")
                    setModel(nil, for: target)
                }
                aiService.refreshConnectedProviders()
            }
        }
    }

    private func refreshModelSelection(
        for provider: AIProvider,
        target: ModelSelectionTarget
    ) {
        if provider == .ollama {
            let availableModels = aiService.ollamaModels
            if let currentModel = currentModel(for: target),
               availableModels.contains(currentModel) {
                return
            }

            if let firstModel = availableModels.first {
                setModel(firstModel, for: target)
                logger.logInfo("Refreshed \(target.logName) Ollama model to: \(firstModel)")
            } else {
                setModel(nil, for: target)
            }
        } else if provider == .customOpenAI {
            let configuredModel = aiService.customOpenAIModelName
            if !configuredModel.isEmpty && currentModel(for: target) != configuredModel {
                setModel(configuredModel, for: target)
                logger.logInfo("Refreshed \(target.logName) Custom OpenAI model to: \(configuredModel)")
            } else if configuredModel.isEmpty {
                setModel(nil, for: target)
            }
        }
    }

    private func currentModel(for target: ModelSelectionTarget) -> String? {
        switch target {
        case .aiEnhancement:
            aiModel
        case .reminderExtraction:
            reminderExtractorModel
        }
    }

    private func setModel(_ model: String?, for target: ModelSelectionTarget) {
        switch target {
        case .aiEnhancement:
            aiModel = model
        case .reminderExtraction:
            reminderExtractorModel = model
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

    /// Whether Apple FM should appear in the provider picker.
    /// Shows when available or when the user can take action (enable AI, wait for download).
    @MainActor
    var isAppleFoundationModelAvailable: Bool {
        switch AppleFoundationModelAvailability.currentStatus {
        case .available, .appleIntelligenceNotEnabled, .modelNotReady:
            return true
        case .deviceNotEligible, .unavailable:
            return false
        }
    }

    /// Get availability status message for Apple Foundation Model
    @MainActor
    var appleFoundationModelStatusMessage: String {
        AppleFoundationModelAvailability.currentStatus.description
    }

    // MARK: - Preset Settings

    var selectedPresetName: String {
        guard let id = selectedPresetId,
              let preset = presetManager.preset(for: id) else {
            return "Select"
        }
        return preset.name
    }

    func selectFirstPresetIfNeeded() {
        if selectedPresetId == nil, let firstPreset = presetManager.visiblePresets.first {
            selectedPresetId = firstPreset.id
            logger.logInfo("Auto-selected first preset: \(firstPreset.name)")
        }
    }

    /// Normalizes a name for comparison by removing all whitespace and lowercasing
    private func normalizeForComparison(_ name: String) -> String {
        name.split(separator: /\s+/).joined().lowercased()
    }
}
