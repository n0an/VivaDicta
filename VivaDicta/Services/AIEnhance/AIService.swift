//
//  AIService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.09
//

import SwiftUI
import os

/// Service responsible for AI-powered text enhancement of transcriptions.
///
/// `AIService` manages connections to various AI providers (OpenAI, Anthropic, Groq, etc.)
/// and handles the enhancement of raw transcriptions using LLM APIs. It also manages
/// ``VivaMode`` configurations that combine transcription and enhancement settings.
///
/// ## Overview
///
/// The service provides:
/// - Multi-provider AI enhancement (OpenAI, Anthropic, Groq, Mistral, Ollama, Apple Foundation Models, etc.)
/// - Mode management (create, update, delete, duplicate ``VivaMode`` instances)
/// - API key verification and storage
/// - Dynamic model fetching for providers like OpenRouter
/// - Foundation Model prewarming for faster on-device enhancement
///
/// ## Usage
///
/// ```swift
/// let aiService = AIService()
///
/// // Check if enhancement is properly configured
/// if aiService.isProperlyConfigured() {
///     let (enhancedText, duration, promptName) = try await aiService.enhance(rawText)
/// }
/// ```
///
/// ## Thread Safety
///
/// This class is marked with `@Observable` for SwiftUI integration. API key operations
/// and provider refreshing should be performed on the main actor.
@Observable
class AIService {
    private let logger = Logger(category: .aiService)

    /// List of AI providers that have valid API keys or are otherwise available.
    public var connectedProviders: [AIProvider] = []
    public var openRouterModels: [String] = []
    public var vercelAIGatewayModels: [String] = []
    public var huggingFaceModels: [String] = []
    public var ollamaModels: [String] = []
    public var modes: [VivaMode] = []

    /// Ollama server URL (configurable, defaults to localhost:11434)
    public var ollamaServerURL: String {
        get {
            userDefaults.string(forKey: UserDefaultsStorage.Keys.ollamaServerURL)
                ?? AIProvider.ollamaDefaultServerURL
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaultsStorage.Keys.ollamaServerURL)
            userDefaults.synchronize()
        }
    }

    /// Custom OpenAI endpoint URL (configurable)
    /// Stored property so @Observable can track changes for UI updates
    public var customOpenAIEndpointURL: String = "" {
        didSet {
            userDefaults.set(customOpenAIEndpointURL, forKey: UserDefaultsStorage.Keys.customOpenAIEndpointURL)
            userDefaults.synchronize()
        }
    }

    /// Custom OpenAI model name (configurable)
    /// Stored property so @Observable can track changes for UI updates
    public var customOpenAIModelName: String = "" {
        didSet {
            userDefaults.set(customOpenAIModelName, forKey: UserDefaultsStorage.Keys.customOpenAIModelName)
            userDefaults.synchronize()
        }
    }

    /// Tracks whether Custom OpenAI configuration has been successfully verified
    /// When false, the provider is not ready for use even if URL/model are set
    public var customOpenAIIsVerified: Bool = false {
        didSet {
            userDefaults.set(customOpenAIIsVerified, forKey: UserDefaultsStorage.Keys.customOpenAIIsVerified)
            userDefaults.synchronize()
        }
    }

    public var onModeChange: ((VivaMode) -> Void)?

    public var selectedModeName: String {
        didSet {
            self.saveSelectedModeName(selectedModeName)
            self.selectedMode = getMode(name: selectedModeName)
        }
    }

    public var selectedMode: VivaMode = VivaMode.defaultMode {
        didSet {
            onModeChange?(selectedMode)
        }
    }

    private let userDefaults = UserDefaultsStorage.shared
    private let baseTimeout: TimeInterval = 30

    /// Service for Apple's on-device Foundation Models (type-erased for iOS version compatibility)
    private var _appleFoundationModelService: Any?

    @available(iOS 26, *)
    private var appleFoundationModelService: AppleFoundationModelService {
        if let service = _appleFoundationModelService as? AppleFoundationModelService {
            return service
        }
        let service = AppleFoundationModelService()
        _appleFoundationModelService = service
        return service
    }

    init() {
        self.selectedModeName = userDefaults.string(forKey: AppGroupCoordinator.selectedVivaModeKey) ?? VivaMode.defaultMode.name

        // Load Custom OpenAI configuration from UserDefaults
        self.customOpenAIEndpointURL = userDefaults.string(forKey: UserDefaultsStorage.Keys.customOpenAIEndpointURL) ?? ""
        self.customOpenAIModelName = userDefaults.string(forKey: UserDefaultsStorage.Keys.customOpenAIModelName) ?? ""
        self.customOpenAIIsVerified = userDefaults.bool(forKey: UserDefaultsStorage.Keys.customOpenAIIsVerified)

        loadModes()
        self.selectedMode = getMode(name: selectedModeName)
        loadSavedOpenRouterModels()
        loadSavedVercelAIGatewayModels()
        loadSavedHuggingFaceModels()
        loadSavedOllamaModels()

        // Refresh connected providers on main actor (needed for Apple availability check)
        Task { @MainActor in
            refreshConnectedProviders()
            if connectedProviders.contains(.openRouter) {
                await fetchOpenRouterModels()
            }
            if connectedProviders.contains(.vercelAIGateway) {
                await fetchVercelAIGatewayModels()
            }
            if connectedProviders.contains(.huggingFace) {
                await fetchHuggingFaceModels()
            }
            // Ollama models are fetched on-demand when user configures Ollama
        }
    }
    
    public func getMode(name: String) -> VivaMode {
        return modes.first { $0.name == name } ?? VivaMode.defaultMode
    }

    /// Reload the selected mode from UserDefaults (used when keyboard or share extension changes the mode)
    public func reloadSelectedModeFromExtension() {
        let savedModeName = userDefaults.string(forKey: AppGroupCoordinator.selectedVivaModeKey) ?? VivaMode.defaultMode.name
        if savedModeName != selectedModeName {
            logger.logInfo("📱 Reloading VivaMode from extension: \(savedModeName)")
            selectedModeName = savedModeName
            selectedMode = getMode(name: savedModeName)
        }
    }
    
    public func addMode(_ mode: VivaMode) {
        modes.append(mode)
        saveModes()
        logger.logInfo("Added new mode: \(mode.name)")
    }
    
    public func updateMode(_ mode: VivaMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            saveModes()
            
            if selectedMode.id == mode.id {
                selectedMode = mode
            }
            
            logger.logInfo("Updated mode: \(mode.name)")
        }
    }
    
    public func deleteMode(_ mode: VivaMode) {
        guard modes.count > 1 else {
            logger.logWarning("Cannot delete last mode")
            return
        }

        modes.removeAll { $0.id == mode.id }

        // If deleted mode was selected, switch to first one
        if selectedMode.id == mode.id {
            selectedModeName = modes[0].name
        }

        saveModes()
        logger.logInfo("Deleted mode: \(mode.name)")
    }

    public func duplicateMode(_ mode: VivaMode) {
        let newName = generateUniqueName(baseName: mode.name)

        let duplicatedMode = VivaMode(
            id: UUID(),
            name: newName,
            transcriptionProvider: mode.transcriptionProvider,
            transcriptionModel: mode.transcriptionModel,
            transcriptionLanguage: mode.transcriptionLanguage,
            userPrompt: mode.userPrompt,
            aiProvider: mode.aiProvider,
            aiModel: mode.aiModel,
            aiEnhanceEnabled: mode.aiEnhanceEnabled
        )

        addMode(duplicatedMode)
        logger.logInfo("Duplicated mode '\(mode.name)' as '\(newName)'")
    }

    /// Generates a unique name for duplicating a mode
    /// "default" → "default 1", "default 1" → "default 2", etc.
    private func generateUniqueName(baseName: String) -> String {
        let trimmedName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract base name and current number if exists
        // Pattern: "Name" or "Name N" where N is a number
        let pattern = /^(.+?)\s+(\d+)$/
        let extractedBaseName: String
        if let match = trimmedName.wholeMatch(of: pattern) {
            extractedBaseName = String(match.1)
        } else {
            extractedBaseName = trimmedName
        }

        // Find the highest number used for this base name
        // Use normalized comparison (whitespace-insensitive)
        var highestNumber = 0
        let normalizedBaseName = normalizeForComparison(extractedBaseName)
        let numberPattern = /^(.+?)\s+(\d+)$/

        for mode in modes {
            let modeName = mode.name.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizeForComparison(modeName) == normalizedBaseName {
                // Exact match with base name means at least 1 exists
                highestNumber = max(highestNumber, 0)
            } else if let match = modeName.wholeMatch(of: numberPattern),
                      normalizeForComparison(String(match.1)) == normalizedBaseName,
                      let num = Int(match.2) {
                highestNumber = max(highestNumber, num)
            }
        }

        return "\(extractedBaseName) \(highestNumber + 1)"
    }

    /// Normalizes a name for comparison by removing all whitespace and lowercasing
    private func normalizeForComparison(_ name: String) -> String {
        name.split(separator: /\s+/).joined().lowercased()
    }

    /// Disables AI enhancement for all modes that use the specified AI provider.
    /// Called when an API key for that provider is deleted.
    public func disableAIEnhancementForModesUsingProvider(_ provider: AIProvider) {
        updateModesMatching(
            { $0.aiEnhanceEnabled && $0.aiProvider == provider },
            transform: { mode in
                VivaMode(
                    id: mode.id,
                    name: mode.name,
                    transcriptionProvider: mode.transcriptionProvider,
                    transcriptionModel: mode.transcriptionModel,
                    transcriptionLanguage: mode.transcriptionLanguage,
                    userPrompt: mode.userPrompt,
                    aiProvider: mode.aiProvider,
                    aiModel: mode.aiModel,
                    aiEnhanceEnabled: false
                )
            },
            logMessage: { "Disabled AI enhancement for mode '\($0.name)' due to API key deletion for provider: \(provider.rawValue)" }
        )
    }

    /// Disables AI enhancement for all modes that use the specified prompt.
    /// Called when that prompt is deleted.
    public func disableAIEnhancementForModesUsingPrompt(promptId: UUID) {
        updateModesMatching(
            { $0.aiEnhanceEnabled && $0.userPrompt?.id == promptId },
            transform: { mode in
                VivaMode(
                    id: mode.id,
                    name: mode.name,
                    transcriptionProvider: mode.transcriptionProvider,
                    transcriptionModel: mode.transcriptionModel,
                    transcriptionLanguage: mode.transcriptionLanguage,
                    userPrompt: nil,
                    aiProvider: mode.aiProvider,
                    aiModel: mode.aiModel,
                    aiEnhanceEnabled: false
                )
            },
            logMessage: { "Disabled AI enhancement for mode '\($0.name)' due to prompt deletion" }
        )
    }

    /// Disables AI enhancement for all modes that use Ollama.
    /// Called when Ollama connection fails.
    public func disableOllamaEnhancementForAllModes() {
        updateModesMatching(
            { $0.aiEnhanceEnabled && $0.aiProvider == .ollama },
            transform: { mode in
                VivaMode(
                    id: mode.id,
                    name: mode.name,
                    transcriptionProvider: mode.transcriptionProvider,
                    transcriptionModel: mode.transcriptionModel,
                    transcriptionLanguage: mode.transcriptionLanguage,
                    userPrompt: mode.userPrompt,
                    aiProvider: nil,
                    aiModel: "",
                    aiEnhanceEnabled: false
                )
            },
            logMessage: { "Disabled AI enhancement for mode '\($0.name)' due to Ollama connection failure" }
        )
    }

    /// Updates all modes that use the specified prompt with the new prompt data.
    /// Called when a prompt is edited to sync changes across all modes using it.
    public func updateModesWithPrompt(_ updatedPrompt: UserPrompt) {
        updateModesMatching(
            { $0.userPrompt?.id == updatedPrompt.id },
            transform: { mode in
                VivaMode(
                    id: mode.id,
                    name: mode.name,
                    transcriptionProvider: mode.transcriptionProvider,
                    transcriptionModel: mode.transcriptionModel,
                    transcriptionLanguage: mode.transcriptionLanguage,
                    userPrompt: updatedPrompt,
                    aiProvider: mode.aiProvider,
                    aiModel: mode.aiModel,
                    aiEnhanceEnabled: mode.aiEnhanceEnabled
                )
            },
            logMessage: { "Updated prompt in mode '\($0.name)' with new prompt data: \(updatedPrompt.title)" }
        )
    }

    private func updateModesMatching(
        _ predicate: (VivaMode) -> Bool,
        transform: (VivaMode) -> VivaMode,
        logMessage: (VivaMode) -> String
    ) {
        var modesUpdated = false

        for (index, mode) in modes.enumerated() {
            if predicate(mode) {
                let updatedMode = transform(mode)
                modes[index] = updatedMode

                if selectedMode.id == mode.id {
                    selectedMode = updatedMode
                }

                modesUpdated = true
                logger.logInfo(logMessage(mode))
            }
        }

        if modesUpdated {
            saveModes()
        }
    }

    public func updateDefaultModeIfNeeded(provider: TranscriptionModelProvider, modelName: String) {
        logger.logInfo("updateDefaultModeIfNeeded called with provider: \(provider.rawValue), modelName: \(modelName)")

        // Find the default mode
        guard let defaultModeIndex = modes.firstIndex(where: { $0.name == "Default" }) else {
            logger.logWarning("Default mode not found")
            return
        }

        let defaultMode = modes[defaultModeIndex]
        logger.logInfo("Default mode found. Current transcriptionModel: '\(defaultMode.transcriptionModel)', isEmpty: \(defaultMode.transcriptionModel.isEmpty)")

        // Only update if the default mode doesn't have a transcription model set
        if defaultMode.transcriptionModel.isEmpty {
            // Create updated mode with the new transcription settings
            let updatedMode = VivaMode(
                id: defaultMode.id,
                name: defaultMode.name,
                transcriptionProvider: provider,
                transcriptionModel: modelName,
                transcriptionLanguage: defaultMode.transcriptionLanguage,
                userPrompt: defaultMode.userPrompt,
                aiProvider: defaultMode.aiProvider,
                aiModel: defaultMode.aiModel,
                aiEnhanceEnabled: defaultMode.aiEnhanceEnabled
            )

            // Update the mode
            modes[defaultModeIndex] = updatedMode
            saveModes()

            // If default mode is currently selected, update the selected mode
            if selectedMode.name == "Default" {
                selectedMode = updatedMode
            }

            logger.logInfo("Updated default mode with first available model: \(modelName) from provider: \(provider.rawValue)")
        } else {
            logger.logInfo("Default mode already has a transcription model set: '\(defaultMode.transcriptionModel)'. Skipping update.")
        }
    }

    private func loadModes() {
        if let savedModesData = userDefaults.data(forKey: AppGroupCoordinator.vivaModesKey),
           let savedModes = try? JSONDecoder().decode([VivaMode].self, from: savedModesData) {
            modes = savedModes
        } else {
            modes = [VivaMode.defaultMode]
        }

        logger.logInfo("Loaded \(self.modes.count) Viva Modes")
    }

    private func saveModes() {
        guard let encoded = try? JSONEncoder().encode(modes) else {
            logger.logError("Failed to encode Viva Modes")
            return
        }
        userDefaults.set(encoded, forKey: AppGroupCoordinator.vivaModesKey)
        userDefaults.synchronize() // Force immediate write to disk
        logger.logInfo("Saved \(self.modes.count) Viva Modes to shared storage")
    }

    private func saveSelectedModeName(_ modeName: String) {
        userDefaults.setValue(modeName, forKey: AppGroupCoordinator.selectedVivaModeKey)
        logger.logInfo("Saved Viva Mode: \(modeName)")
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: UserDefaultsStorage.Keys.openRouterModels) as? [String] {
            openRouterModels = savedModels
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: UserDefaultsStorage.Keys.openRouterModels)
    }

    private func loadSavedVercelAIGatewayModels() {
        if let savedModels = userDefaults.array(forKey: UserDefaultsStorage.Keys.vercelAIGatewayModels) as? [String] {
            vercelAIGatewayModels = savedModels
        }
    }

    private func saveVercelAIGatewayModels() {
        userDefaults.set(vercelAIGatewayModels, forKey: UserDefaultsStorage.Keys.vercelAIGatewayModels)
    }

    private func loadSavedHuggingFaceModels() {
        if let savedModels = userDefaults.array(forKey: UserDefaultsStorage.Keys.huggingFaceModels) as? [String] {
            huggingFaceModels = savedModels
        }
    }

    private func saveHuggingFaceModels() {
        userDefaults.set(huggingFaceModels, forKey: UserDefaultsStorage.Keys.huggingFaceModels)
    }

    private func loadSavedOllamaModels() {
        if let savedModels = userDefaults.array(forKey: UserDefaultsStorage.Keys.ollamaModels) as? [String] {
            ollamaModels = savedModels
        }
    }

    private func saveOllamaModels() {
        userDefaults.set(ollamaModels, forKey: UserDefaultsStorage.Keys.ollamaModels)
    }

    // MARK: - Configuration validation

    /// Validates that AI enhancement is properly configured for the current mode.
    ///
    /// Checks include:
    /// - AI enhancement is enabled in the current mode
    /// - An AI provider is selected
    /// - A model is selected
    /// - The provider has valid credentials (API key, endpoint URL, or is available locally)
    /// - A prompt with instructions is selected
    ///
    /// - Returns: `true` if enhancement can proceed, `false` otherwise.
    public func isProperlyConfigured() -> Bool {
        // Check if AI enhancement is enabled
        guard selectedMode.aiEnhanceEnabled else {
            logger.logInfo("AI enhancement is disabled for mode: \(self.selectedMode.name)")
            return false
        }

        // Check if AI provider is selected
        guard let aiProvider = selectedMode.aiProvider else {
            logger.logWarning("No AI provider selected for mode: \(self.selectedMode.name)")
            return false
        }

        // Check if AI model is selected (not empty)
        guard !selectedMode.aiModel.isEmpty else {
            logger.logWarning("No AI model selected for mode: \(self.selectedMode.name)")
            return false
        }

        // Apple provider doesn't need API key but needs to be available
        if aiProvider == .apple {
            guard connectedProviders.contains(.apple) else {
                logger.logWarning("Apple Foundation Model not available on this device")
                return false
            }
        } else if aiProvider == .ollama {
            // Ollama doesn't need API key, just needs model selected
            // Connection will be verified at enhancement time
            guard !selectedMode.aiModel.isEmpty else {
                logger.logWarning("No Ollama model selected")
                return false
            }
        } else if aiProvider == .customOpenAI {
            // Custom OpenAI needs URL and model configured
            guard !customOpenAIEndpointURL.isEmpty else {
                logger.logWarning("Custom OpenAI endpoint URL not configured")
                return false
            }
            guard !customOpenAIModelName.isEmpty else {
                logger.logWarning("Custom OpenAI model name not configured")
                return false
            }
        } else {
            // Check if API key exists for the selected cloud provider
            guard getAPIKey(for: aiProvider) != nil else {
                logger.logWarning("No API key configured for provider: \(aiProvider.rawValue)")
                return false
            }
        }

        // Check if a prompt is selected
        guard let userPrompt = selectedMode.userPrompt,
              !userPrompt.promptInstructions.isEmpty else {
            logger.logWarning("No prompt selected or prompt is empty for mode: \(self.selectedMode.name)")
            return false
        }

        logger.logInfo("AI enhancement is properly configured for mode: \(self.selectedMode.name)")
        return true
    }

    // MARK: - Foundation Model Prewarm

    /// Prewarm Apple Foundation Model if the current mode uses Apple as AI provider.
    /// Called when recording starts - prewarming prepares the model for use within seconds.
    /// Uses split instructions (role + rules + vocabulary) and prompt prefix (user enhancement style).
    @MainActor
    public func prewarmFoundationModelIfNeeded() {
        guard selectedMode.aiEnhanceEnabled,
              selectedMode.aiProvider == .apple,
              AppleFoundationModelAvailability.isAvailable else {
            return
        }

        if #available(iOS 26, *) {
            let instructions = getFoundationModelInstructions()
            let promptPrefix = getFoundationModelPromptPrefix()
            logger.logInfo("Prewarming Apple Foundation Model for mode: \(self.selectedMode.name)")
            appleFoundationModelService.prewarm(instructions: instructions, promptPrefix: promptPrefix)
        }
    }

    /// Cancel any prewarmed Foundation Model session.
    /// Call this when recording is cancelled to free memory.
    @MainActor
    public func cancelFoundationModelPrewarm() {
        if #available(iOS 26, *) {
            appleFoundationModelService.cancelPrewarm()
        }
    }

    // MARK: - Enhance methods

    /// Enhances transcribed text using the configured AI provider.
    ///
    /// - Parameter text: The raw transcribed text to enhance.
    ///
    /// - Returns: A tuple containing:
    ///   - The enhanced text
    ///   - The duration of the enhancement request in seconds
    ///   - The name of the prompt used (if any)
    ///
    /// - Throws: ``EnhancementError`` if enhancement fails, or `CancellationError` if cancelled.
    public func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()

        let promptName = selectedMode.userPrompt?.title

        do {
            let result = try await makeRequest(text: text)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            return (result, duration, promptName)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.logError("AI Enhancement failed: \(error.localizedDescription)")
            throw error
        }
    }

    // TODO: Add method to generate tags/keywords for transcriptions
    // public func generateTags(for text: String, maxTags: Int = 10) async throws -> [String] {
    //     // Use LLM to analyze text and extract key topics, themes, entities
    //     // Return array of meaningful tags for Spotlight indexing
    //     // Consider using a specific prompt optimized for tag extraction
    // }

    /// Formats the transcribed text for the LLM request.
    /// Wraps in <TRANSCRIPT> tags if enabled in the user's prompt settings.
    private func formatTranscriptForLLM(_ text: String) -> String {
        let shouldWrap = selectedMode.userPrompt?.wrapInTranscriptTags ?? true
        if shouldWrap {
            return "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        } else {
            return text
        }
    }

    private func makeRequest(text: String) async throws -> String {
        guard let aiProvider = self.selectedMode.aiProvider else {
            throw EnhancementError.notConfigured
        }

        guard !text.isEmpty else {
            return ""
        }

        // Handle Apple Foundation Model (on-device)
        if aiProvider == .apple {
            if #available(iOS 26, *) {
                let instructions = getFoundationModelInstructions()
                let promptPrefix = getFoundationModelPromptPrefix()
                let wrapInTags = selectedMode.userPrompt?.wrapInTranscriptTags ?? true
                logger.logDebug("AI Enhancement - Using Apple Foundation Model")
                logger.logDebug("AI Enhancement - Instructions: \(instructions)")
                logger.logDebug("AI Enhancement - Prompt Prefix: \(promptPrefix)")
                logger.logDebug("AI Enhancement - Input Text: \(text)")
                return try await appleFoundationModelService.enhance(text, instructions: instructions, promptPrefix: promptPrefix, wrapInTranscriptTags: wrapInTags)
            } else {
                throw EnhancementError.notConfigured
            }
        }

        // Handle Ollama (local server)
        if aiProvider == .ollama {
            return try await makeOllamaRequest(text: text)
        }

        // Handle Custom OpenAI (user-configured endpoint)
        if aiProvider == .customOpenAI {
            return try await makeCustomOpenAIRequest(text: text)
        }

        // Cloud providers - compute system message only when needed
        let systemMessage = getSystemMessage()

        // Cloud providers require API key
        guard let apiKey = self.getAPIKey(for: aiProvider) else {
            throw EnhancementError.notConfigured
        }

        let formattedText = formatTranscriptForLLM(text)

        logger.logDebug("AI Enhancement - System Message: \(systemMessage)")
        logger.logDebug("AI Enhancement - User Message: \(formattedText)")

        switch aiProvider {
        case .anthropic:
            let requestBody: [String: Any] = [
                "model": selectedMode.aiModel,
                "max_tokens": 8192,
                "system": systemMessage,
                "messages": [
                    ["role": "user", "content": formattedText]
                ]
            ]
            
            var request = URLRequest(url: URL(string: aiProvider.baseURL)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = baseTimeout
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
            
            do {
                // Check for cancellation before making network request
                try Task.checkCancellation()

                let (data, response) = try await URLSession.shared.data(for: request)

                // Check for cancellation after network request
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnhancementError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let content = jsonResponse["content"] as? [[String: Any]],
                          let firstContent = content.first,
                          let enhancedText = firstContent["text"] as? String else {
                        throw EnhancementError.enhancementFailed
                    }

                    let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    return filteredText
                } else if httpResponse.statusCode == 429 {
                    throw EnhancementError.rateLimitExceeded
                } else if (500...599).contains(httpResponse.statusCode) {
                    throw EnhancementError.serverError
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }

            } catch is CancellationError {
                throw CancellationError()
            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }
            
        default:
            let url = URL(string: aiProvider.baseURL)!
            var request = URLRequest(url: url)
            
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = baseTimeout

            let messages: [[String: Any]] = [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": formattedText]
            ]

            var requestBody: [String: Any] = [
                "model": selectedMode.aiModel,
                "messages": messages,
                "temperature": selectedMode.aiModel.lowercased().hasPrefix("gpt-5") ? 1.0 : 0.3,
                "stream": false
            ]
            
            // Add reasoning_effort parameter if the model supports it
            if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: selectedMode.aiModel) {
                requestBody["reasoning_effort"] = reasoningEffort
            }

            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            do {
                // Check for cancellation before making network request
                try Task.checkCancellation()

                let (data, response) = try await URLSession.shared.data(for: request)

                // Check for cancellation after network request
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnhancementError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = jsonResponse["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let enhancedText = message["content"] as? String else {
                        throw EnhancementError.enhancementFailed
                    }

                    let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    return filteredText
                } else if httpResponse.statusCode == 429 {
                    throw EnhancementError.rateLimitExceeded
                } else if (500...599).contains(httpResponse.statusCode) {
                    throw EnhancementError.serverError
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }

            } catch is CancellationError {
                throw CancellationError()
            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - System Message (Cloud Providers)

    private func getSystemMessage() -> String {
        var customVocabularySection = ""
        let customVocabularyWords = CustomVocabulary.getTerms()
        if !customVocabularyWords.isEmpty {
            let vocabularyString = customVocabularyWords.joined(separator: ", ")
            customVocabularySection = "\n\n<CUSTOM_VOCABULARY>Important Vocabulary: \(vocabularyString)\n</CUSTOM_VOCABULARY>"
        }

        let promptInstructions = selectedMode.userPrompt?.promptInstructions ?? ""
        let useSystemTemplate = selectedMode.userPrompt?.useSystemTemplate ?? true

        if useSystemTemplate {
            return PromptsTemplates.systemPrompt(with: promptInstructions) + customVocabularySection
        } else {
            // User wants full control - use only their instructions + vocabulary
            return promptInstructions + customVocabularySection
        }
    }

    // MARK: - Foundation Model Prompts (Apple)

    /// Returns instructions for LanguageModelSession (role + core rules + vocabulary)
    /// Used with LanguageModelSession(instructions:)
    private func getFoundationModelInstructions() -> String {
        let useSystemTemplate = selectedMode.userPrompt?.useSystemTemplate ?? true
        let words = CustomVocabulary.getTerms()

        if useSystemTemplate {
            let customVocabulary = words.isEmpty ? nil : words.joined(separator: ", ")
            return PromptsTemplates.foundationModelInstructions(customVocabulary: customVocabulary)
        } else {
            // User wants full control - use only their instructions via promptPrefix
            // But still include custom vocabulary if available
            if words.isEmpty {
                return ""
            }
            let vocabularyString = words.joined(separator: ", ")
            return "<CUSTOM_VOCABULARY>Important Vocabulary: \(vocabularyString)</CUSTOM_VOCABULARY>"
        }
    }

    /// Returns prompt prefix for prewarm (user prompt instructions only)
    /// Used with session.prewarm(promptPrefix:)
    private func getFoundationModelPromptPrefix() -> String {
        let promptInstructions = selectedMode.userPrompt?.promptInstructions ?? ""
        let useSystemTemplate = selectedMode.userPrompt?.useSystemTemplate ?? true

        if useSystemTemplate {
            return PromptsTemplates.foundationModelPromptPrefix(promptInstructions: promptInstructions)
        } else {
            // User wants full control - use their instructions directly
            return promptInstructions
        }
    }

    // MARK: - Ollama Methods

    /// Makes an enhancement request to the local Ollama server
    private func makeOllamaRequest(text: String) async throws -> String {
        let serverURL = ollamaServerURL
        guard let url = URL(string: "\(serverURL)/v1/chat/completions") else {
            throw EnhancementError.customError("Invalid Ollama server URL: \(serverURL)")
        }

        let systemMessage = getSystemMessage()
        let formattedText = formatTranscriptForLLM(text)

        logger.logDebug("AI Enhancement - Using Ollama at \(serverURL)")
        logger.logDebug("AI Enhancement - Model: \(self.selectedMode.aiModel)")
        logger.logDebug("AI Enhancement - System Message: \(systemMessage)")
        logger.logDebug("AI Enhancement - User Message: \(formattedText)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // No Authorization header needed for Ollama
        request.timeoutInterval = 120 // Longer timeout for local inference

        let requestBody: [String: Any] = [
            "model": selectedMode.aiModel,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": formattedText]
            ],
            "temperature": 0.3,
            "stream": false
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            try Task.checkCancellation()

            let (data, response) = try await URLSession.shared.data(for: request)

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = jsonResponse["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let enhancedText = message["content"] as? String else {
                    throw EnhancementError.enhancementFailed
                }

                let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                return filteredText

            case 404:
                throw EnhancementError.customError("Model '\(self.selectedMode.aiModel)' not found. Run 'ollama pull \(self.selectedMode.aiModel)' on your Mac/server to download it.")

            case 500...599:
                throw EnhancementError.serverError

            default:
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw EnhancementError.customError("Ollama error (HTTP \(httpResponse.statusCode)): \(errorString)")
            }

        } catch is CancellationError {
            throw CancellationError()
        } catch let error as EnhancementError {
            throw error
        } catch let error as URLError {
            if error.code == .cannotConnectToHost || error.code == .timedOut {
                throw EnhancementError.customError("Cannot connect to Ollama at \(serverURL). Make sure Ollama is running.")
            }
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }

    /// Fetches available models from the Ollama server
    public func fetchOllamaModels() async {
        let serverURL = ollamaServerURL

        // Try OpenAI-compatible endpoint first
        guard let url = URL(string: "\(serverURL)/v1/models") else {
            logger.logError("Invalid Ollama server URL: \(serverURL)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5 // Short timeout for local service

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.logWarning("Ollama OpenAI-compatible endpoint not responding, trying native endpoint")
                await fetchOllamaModelsNative()
                return
            }

            // Parse OpenAI-compatible response
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.logError("Failed to parse Ollama models response")
                await fetchOllamaModelsNative()
                return
            }

            let models = dataArray.compactMap { $0["id"] as? String }.sorted()

            await MainActor.run {
                self.ollamaModels = models
                self.saveOllamaModels()
            }

            logger.logInfo("Successfully fetched \(models.count) Ollama models via OpenAI endpoint")

        } catch {
            logger.logWarning("Failed to fetch Ollama models via OpenAI endpoint: \(error.localizedDescription)")
            await fetchOllamaModelsNative()
        }
    }

    /// Fallback to native Ollama API endpoint for fetching models
    private func fetchOllamaModelsNative() async {
        let serverURL = ollamaServerURL
        guard let url = URL(string: "\(serverURL)/api/tags") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.logError("Ollama native endpoint not responding")
                return
            }

            // Parse native Ollama response
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsArray = jsonResponse["models"] as? [[String: Any]] else {
                logger.logError("Failed to parse Ollama native models response")
                return
            }

            let models = modelsArray.compactMap { $0["name"] as? String }.sorted()

            await MainActor.run {
                self.ollamaModels = models
                self.saveOllamaModels()
            }

            logger.logInfo("Successfully fetched \(models.count) Ollama models via native endpoint")

        } catch {
            logger.logError("Failed to fetch Ollama models via native endpoint: \(error.localizedDescription)")
        }
    }

    /// Checks if Ollama server is reachable
    public func checkOllamaConnection() async -> Bool {
        let serverURL = ollamaServerURL
        guard let url = URL(string: "\(serverURL)/api/tags") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    /// Verifies Ollama setup and returns status message
    public func verifyOllamaSetup() async -> (success: Bool, message: String) {
        // Check server connectivity
        let isConnected = await checkOllamaConnection()

        if !isConnected {
            return (false, "Cannot connect to Ollama server at \(ollamaServerURL)")
        }

        // Fetch available models
        await fetchOllamaModels()

        if ollamaModels.isEmpty {
            return (false, "Connected to Ollama but no models found. Run 'ollama pull llama3.2' on your Mac/server to download a model.")
        }

        return (true, "Connected successfully. Found \(ollamaModels.count) model(s).")
    }

    // MARK: - Custom OpenAI Methods

    /// Makes an enhancement request to the custom OpenAI-compatible endpoint
    private func makeCustomOpenAIRequest(text: String) async throws -> String {
        let endpointURL = customOpenAIEndpointURL
        let modelName = customOpenAIModelName

        guard !endpointURL.isEmpty else {
            throw EnhancementError.customError("Custom AI endpoint URL is not configured")
        }

        guard !modelName.isEmpty else {
            throw EnhancementError.customError("Custom AI model name is not configured")
        }

        // Use URL directly - user provides the full chat/completions endpoint
        guard let url = URL(string: endpointURL) else {
            throw EnhancementError.customError("Invalid Custom AI endpoint URL: \(endpointURL)")
        }

        let systemMessage = getSystemMessage()
        let formattedText = formatTranscriptForLLM(text)

        logger.logDebug("AI Enhancement - Using Custom OpenAI at \(endpointURL)")
        logger.logDebug("AI Enhancement - Model: \(modelName)")
        logger.logDebug("AI Enhancement - System Message: \(systemMessage)")
        logger.logDebug("AI Enhancement - User Message: \(formattedText)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if configured
        let apiKey = getAPIKey(for: .customOpenAI)
        if let apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = 120 // Longer timeout for potentially slow endpoints

        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": formattedText]
            ],
            "temperature": 0.3,
            "stream": false
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            try Task.checkCancellation()

            let (data, response) = try await URLSession.shared.data(for: request)

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = jsonResponse["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let enhancedText = message["content"] as? String else {
                    throw EnhancementError.enhancementFailed
                }

                let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                return filteredText

            case 401:
                throw EnhancementError.customError("Authentication failed. Check your API key.")

            case 404:
                throw EnhancementError.customError("Model '\(modelName)' not found on the server.")

            case 500...599:
                throw EnhancementError.serverError

            default:
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw EnhancementError.customError("Custom AI provider error (HTTP \(httpResponse.statusCode)): \(errorString)")
            }

        } catch is CancellationError {
            throw CancellationError()
        } catch let error as EnhancementError {
            throw error
        } catch let error as URLError {
            if error.code == .cannotConnectToHost || error.code == .timedOut {
                throw EnhancementError.customError("Cannot connect to \(endpointURL). Check the URL and try again.")
            }
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }

    /// Verifies Custom OpenAI setup and returns status message
    public func verifyCustomOpenAISetup() async -> (success: Bool, message: String) {
        let endpointURL = customOpenAIEndpointURL
        let modelName = customOpenAIModelName

        // Check URL is configured
        guard !endpointURL.isEmpty else {
            return (false, "Endpoint URL is not configured")
        }

        // Validate URL format
        guard URL(string: endpointURL) != nil else {
            return (false, "Invalid endpoint URL format")
        }

        // Check model name is configured
        guard !modelName.isEmpty else {
            return (false, "Model name is not configured")
        }

        // Test connection with a minimal chat completions request
        return await testCustomOpenAIEndpoint()
    }

    /// Tests the Custom OpenAI endpoint with a minimal request and returns detailed status
    private func testCustomOpenAIEndpoint() async -> (success: Bool, message: String) {
        let endpointURL = customOpenAIEndpointURL
        let modelName = customOpenAIModelName

        logger.logNotice("🔧 Custom AI Test - URL: '\(endpointURL)'")
        logger.logNotice("🔧 Custom AI Test - Model: '\(modelName)'")

        // Use URL directly - user provides the full chat/completions endpoint (matches VoiceInk approach)
        guard let url = URL(string: endpointURL) else {
            logger.logError("🔧 Custom AI Test - Invalid URL: '\(endpointURL)'")
            return (false, "Invalid endpoint URL format")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Add API key if configured
        let apiKey = getAPIKey(for: .customOpenAI)
        let hasApiKey = apiKey != nil && !apiKey!.isEmpty
        logger.logNotice("🔧 Custom OpenAI Test - API Key present: \(hasApiKey)")

        if let apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Minimal test request - match VoiceInk's approach (no max_tokens)
        let testBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: testBody) else {
            logger.logError("🔧 Custom OpenAI Test - Failed to serialize request body")
            return (false, "Failed to create request")
        }
        request.httpBody = bodyData

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            logger.logNotice("🔧 Custom OpenAI Test - Request body: \(bodyString)")
        }

        do {
            logger.logNotice("🔧 Custom OpenAI Test - Sending request...")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.logError("🔧 Custom OpenAI Test - Response is not HTTPURLResponse")
                return (false, "Invalid response from server")
            }

            let responseString = String(data: data, encoding: .utf8) ?? "(unable to decode)"
            logger.logNotice("🔧 Custom OpenAI Test - HTTP Status: \(httpResponse.statusCode)")
            logger.logNotice("🔧 Custom OpenAI Test - Response: \(responseString.prefix(500))")

            switch httpResponse.statusCode {
            case 200:
                logger.logNotice("🔧 Custom OpenAI Test - SUCCESS!")
                return (true, "Connected successfully")
            case 401:
                logger.logError("🔧 Custom OpenAI Test - 401 Unauthorized")
                return (false, "Authentication failed. Check your API key.")
            case 404:
                logger.logError("🔧 Custom OpenAI Test - 404 Not Found")
                return (false, "Endpoint not found. Check the URL.")
            case 400:
                // 400 could mean various things - try to extract error message
                logger.logError("🔧 Custom OpenAI Test - 400 Bad Request")
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    logger.logError("🔧 Custom OpenAI Test - Error message: \(message)")
                    return (false, message)
                }
                return (false, "Bad request: \(responseString.prefix(200))")
            case 500...599:
                logger.logError("🔧 Custom OpenAI Test - Server error")
                return (false, "Server error (\(httpResponse.statusCode)). Try again later.")
            default:
                logger.logError("🔧 Custom OpenAI Test - Unexpected status: \(httpResponse.statusCode)")
                return (false, "HTTP \(httpResponse.statusCode): \(responseString.prefix(200))")
            }
        } catch let error as URLError {
            logger.logError("🔧 Custom OpenAI Test - URLError: \(error.code.rawValue) - \(error.localizedDescription)")
            switch error.code {
            case .cannotConnectToHost:
                return (false, "Cannot connect to server. Check the URL and that the server is running.")
            case .timedOut:
                return (false, "Connection timed out. Server may be slow or unreachable.")
            case .notConnectedToInternet:
                return (false, "No internet connection.")
            default:
                return (false, "Connection error: \(error.localizedDescription)")
            }
        } catch {
            logger.logError("🔧 Custom OpenAI Test - Error: \(error)")
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    /// Clears Custom OpenAI configuration
    public func clearCustomOpenAIConfiguration() {
        customOpenAIEndpointURL = ""
        customOpenAIModelName = ""
        customOpenAIIsVerified = false
        KeychainService.shared.delete(forKey: AIProvider.customOpenAI.keychainKey)
    }

    /// Disables AI enhancement for all modes that use Custom OpenAI.
    /// Called when Custom OpenAI configuration is cleared.
    public func disableCustomOpenAIEnhancementForAllModes() {
        updateModesMatching(
            { $0.aiEnhanceEnabled && $0.aiProvider == .customOpenAI },
            transform: { mode in
                VivaMode(
                    id: mode.id,
                    name: mode.name,
                    transcriptionProvider: mode.transcriptionProvider,
                    transcriptionModel: mode.transcriptionModel,
                    transcriptionLanguage: mode.transcriptionLanguage,
                    userPrompt: mode.userPrompt,
                    aiProvider: nil,
                    aiModel: "",
                    aiEnhanceEnabled: false
                )
            },
            logMessage: { "Disabled AI enhancement for mode '\($0.name)' due to Custom OpenAI configuration removal" }
        )
    }

    // MARK: - API Keys methods
    @MainActor
    public func refreshConnectedProviders() {
        var providers: [AIProvider] = []

        // Add Apple provider if Foundation Models are available (no API key needed)
        if AppleFoundationModelAvailability.isAvailable {
            providers.append(.apple)
        }

        // Add Ollama provider (always available, connection checked on-demand)
        providers.append(.ollama)

        // Add Custom OpenAI provider if configured AND verified
        if !customOpenAIEndpointURL.isEmpty && !customOpenAIModelName.isEmpty && customOpenAIIsVerified {
            providers.append(.customOpenAI)
        }

        // Add cloud providers that have API keys configured
        providers += AIProvider.allCases.filter { provider in
            provider.requiresAPIKey &&
            provider.apiKey != nil
        }

        connectedProviders = providers
    }
    
    public func saveAPIKey(_ key: String, for provider: AIProvider) async -> Bool {
        let isValid = await verifyAPIKey(key, provider: provider)
        
        await MainActor.run {
            if isValid {
                KeychainService.shared.save(key, forKey: provider.keychainKey)

                // Refresh connected providers to trigger UI update
                self.refreshConnectedProviders()
            }
        }
        
        // Fetch models for providers that support dynamic model fetching
        if isValid && provider == .openRouter {
            await fetchOpenRouterModels()
        }
        if isValid && provider == .vercelAIGateway {
            await fetchVercelAIGatewayModels()
        }
        if isValid && provider == .huggingFace {
            await fetchHuggingFaceModels()
        }

        return isValid
    }

    private func getAPIKey(for provider: AIProvider) -> String? {
        return provider.apiKey
    }
    
    private func verifyAPIKey(_ key: String, provider: AIProvider) async -> Bool {
        switch provider {
        case .apple, .ollama, .customOpenAI:
            // Apple, Ollama, and Custom OpenAI don't require API key verification through standard flow
            return true
        case .anthropic:
            return await verifyAnthropicAPIKey(key)
        case .grok:
            return await verifyGrokAPIKey(key)
        case .elevenLabs:
            return await verifyElevenLabsAPIKey(key)
        case .deepgram:
            return await verifyDeepgramAPIKey(key)
        case .mistral:
            return await verifyMistralAPIKey(key)
        case .soniox:
            return await verifySonioxAPIKey(key)
        case .vercelAIGateway:
            return await verifyVercelAIGatewayAPIKey(key)
        case .huggingFace:
            return await verifyHuggingFaceAPIKey(key)
        default:
            return await verifyOpenAICompatibleAPIKey(key, provider: provider)
        }
    }
    
    private func verifyOpenAICompatibleAPIKey(_ key: String, provider: AIProvider) async -> Bool {
        let url = URL(string: provider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let testBody: [String: Any] = [
            "model": provider.defaultModel,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        logger.logNotice("🔑 Verifying API key for \(provider.rawValue) provider at \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.logNotice("🔑 API key verification failed for \(provider.rawValue): Invalid response")
                return false
            }

            let isValid = httpResponse.statusCode == 200

            if !isValid {
                // Log the exact API error response
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.logNotice("🔑 API key verification failed for \(provider.rawValue) - Status: \(httpResponse.statusCode) - \(exactAPIError)")
                } else {
                    logger.logNotice("🔑 API key verification failed for \(provider.rawValue) - Status: \(httpResponse.statusCode)")
                }
            }
            
            return isValid
            
        } catch {
            logger.logNotice("🔑 API key verification failed for \(provider.rawValue): \(error.localizedDescription)")
            return false
        }
    }
    
    private func verifyAnthropicAPIKey(_ key: String) async -> Bool {
        let url = URL(string: AIProvider.anthropic.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let testBody: [String: Any] = [
            "model": AIProvider.anthropic.defaultModel,
            "max_tokens": 1024,
            "system": "You are a test system.",
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
            
        } catch {
            return false
        }
    }
    
    private func verifyElevenLabsAPIKey(_ key: String) async -> Bool {
        let url = URL(string: "https://api.elevenlabs.io/v1/user")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "xi-api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200

            if let body = String(data: data, encoding: .utf8) {
                logger.logInfo("ElevenLabs verification response: \(body)")
            }

            return isValid
            
        } catch {
            return false
        }
    }
    
    private func verifyDeepgramAPIKey(_ key: String) async -> Bool {
        let url = URL(string: "https://api.deepgram.com/v1/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Token \(key)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
            
        } catch {
            logger.logError("Deepgram API key verification failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func verifyMistralAPIKey(_ key: String) async -> Bool {
        let url = URL(string: "https://api.mistral.ai/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.logError("Mistral API key verification failed: Invalid response from server.")
                return false
            }

            if httpResponse.statusCode == 200 {
                return true
            } else {
                if let body = String(data: data, encoding: .utf8) {
                    logger.logError("Mistral API key verification failed with status code \(httpResponse.statusCode): \(body)")
                } else {
                    logger.logError("Mistral API key verification failed with status code \(httpResponse.statusCode) and no response body.")
                }
                return false
            }
        } catch {
            logger.logError("Mistral API key verification failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func verifySonioxAPIKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.soniox.com/v1/files") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            return httpResponse.statusCode == 200
        } catch {
            logger.logError("Soniox API key verification failed: \(error.localizedDescription)")
            return false
        }
    }

    private func verifyVercelAIGatewayAPIKey(_ key: String) async -> Bool {
        // Use /v1/credits endpoint to verify API key
        let url = URL(string: "https://ai-gateway.vercel.sh/v1/credits")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        logger.logNotice("🔑 Verifying Vercel AI Gateway API key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.logNotice("🔑 Vercel AI Gateway API key verification failed: Invalid response")
                return false
            }

            let isValid = httpResponse.statusCode == 200

            if !isValid {
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.logNotice("🔑 Vercel AI Gateway API key verification failed - Status: \(httpResponse.statusCode) - \(exactAPIError)")
                } else {
                    logger.logNotice("🔑 Vercel AI Gateway API key verification failed - Status: \(httpResponse.statusCode)")
                }
            }

            return isValid

        } catch {
            logger.logNotice("🔑 Vercel AI Gateway API key verification failed: \(error.localizedDescription)")
            return false
        }
    }

    private func verifyGrokAPIKey(_ key: String) async -> Bool {
        let url = URL(string: AIProvider.grok.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let testBody: [String: Any] = [
            "model": AIProvider.grok.defaultModel,
            "messages": [
                ["role": "user", "content": "test"]
            ],
            "max_tokens": 1
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        logger.logNotice("🔑 Verifying Grok API key at \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.logNotice("🔑 Grok API key verification failed: Invalid response")
                return false
            }

            let isValid = httpResponse.statusCode == 200

            if !isValid {
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.logNotice("🔑 Grok API key verification failed - Status: \(httpResponse.statusCode) - \(exactAPIError)")
                } else {
                    logger.logNotice("🔑 Grok API key verification failed - Status: \(httpResponse.statusCode)")
                }
            }

            return isValid

        } catch {
            logger.logNotice("🔑 Grok API key verification failed: \(error.localizedDescription)")
            return false
        }
    }

    private func verifyHuggingFaceAPIKey(_ key: String) async -> Bool {
        let url = URL(string: AIProvider.huggingFace.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let testBody: [String: Any] = [
            "model": AIProvider.huggingFace.defaultModel,
            "messages": [
                ["role": "user", "content": "test"]
            ],
            "max_tokens": 1
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)

        logger.logNotice("🔑 Verifying HuggingFace API key at \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.logNotice("🔑 HuggingFace API key verification failed: Invalid response")
                return false
            }

            let isValid = httpResponse.statusCode == 200

            if !isValid {
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.logNotice("🔑 HuggingFace API key verification failed - Status: \(httpResponse.statusCode) - \(exactAPIError)")
                } else {
                    logger.logNotice("🔑 HuggingFace API key verification failed - Status: \(httpResponse.statusCode)")
                }
            }

            return isValid

        } catch {
            logger.logNotice("🔑 HuggingFace API key verification failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Dynamic Models methods
    public func getAvailableModels(for provider: AIProvider) -> [String] {
        if provider == .openRouter {
            return openRouterModels
        }
        if provider == .vercelAIGateway {
            return vercelAIGatewayModels
        }
        if provider == .huggingFace {
            return huggingFaceModels
        }
        if provider == .ollama {
            return ollamaModels
        }
        if provider == .customOpenAI {
            // Return the configured model name as a single-item array
            return customOpenAIModelName.isEmpty ? [] : [customOpenAIModelName]
        }
        return provider.availableModels
    }
    
    public func fetchOpenRouterModels() async {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.logError("Failed to fetch OpenRouter models: Invalid HTTP response")
                // Preserve existing cached models on failure
                return
            }

            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.logError("Failed to parse OpenRouter models JSON")
                // Preserve existing cached models on failure
                return
            }

            let models = dataArray.compactMap { $0["id"] as? String }
            await MainActor.run {
                self.openRouterModels = models.sorted()
                self.saveOpenRouterModels()
            }
            logger.logInfo("Successfully fetched \(models.count) OpenRouter models.")

        } catch {
            logger.logError("Error fetching OpenRouter models: \(error.localizedDescription)")
            // Preserve existing cached models on failure
        }
    }

    public func fetchVercelAIGatewayModels() async {
        let url = URL(string: "https://ai-gateway.vercel.sh/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.logError("Failed to fetch Vercel AI Gateway models: Invalid HTTP response")
                // Preserve existing cached models on failure
                return
            }

            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.logError("Failed to parse Vercel AI Gateway models JSON")
                // Preserve existing cached models on failure
                return
            }

            // Filter for language models only (exclude embeddings, image models)
            let totalCount = dataArray.count
            let models = dataArray
                .filter { ($0["type"] as? String) == "language" }
                .compactMap { $0["id"] as? String }

            // Log filtering results for debugging API changes
            if models.isEmpty && totalCount > 0 {
                logger.logWarning("Vercel AI Gateway: Received \(totalCount) models but none matched type 'language'. API response format may have changed.")
            } else if models.count < totalCount {
                logger.logInfo("Vercel AI Gateway: Filtered \(totalCount) models to \(models.count) language models.")
            }

            await MainActor.run {
                self.vercelAIGatewayModels = models.sorted()
                self.saveVercelAIGatewayModels()
            }
            logger.logInfo("Successfully fetched \(models.count) Vercel AI Gateway models.")

        } catch {
            logger.logError("Error fetching Vercel AI Gateway models: \(error.localizedDescription)")
            // Preserve existing cached models on failure
        }
    }

    public func fetchHuggingFaceModels() async {
        let url = URL(string: "https://router.huggingface.co/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.logError("Failed to fetch HuggingFace models: Invalid HTTP response")
                // Preserve existing cached models on failure
                return
            }

            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.logError("Failed to parse HuggingFace models JSON")
                // Preserve existing cached models on failure
                return
            }

            // Filter for text-to-text models only (exclude image, video, speech models)
            let totalCount = dataArray.count
            var missingArchitectureCount = 0
            var nonTextModelsCount = 0

            let models = dataArray
                .filter { model in
                    guard let architecture = model["architecture"] as? [String: Any],
                          let inputModalities = architecture["input_modalities"] as? [String],
                          let outputModalities = architecture["output_modalities"] as? [String] else {
                        missingArchitectureCount += 1
                        return false
                    }
                    // Include only text-in, text-out models
                    let isTextToText = inputModalities == ["text"] && outputModalities == ["text"]
                    if !isTextToText {
                        nonTextModelsCount += 1
                    }
                    return isTextToText
                }
                .compactMap { $0["id"] as? String }

            // Log filtering results for debugging API changes
            if missingArchitectureCount > 0 {
                logger.logDebug("HuggingFace: Skipped \(missingArchitectureCount) models with missing or malformed architecture data.")
            }
            if models.isEmpty && totalCount > 0 {
                logger.logWarning("HuggingFace: Received \(totalCount) models but none matched text-to-text filter. API response format may have changed.")
            } else if models.count < totalCount {
                logger.logInfo("HuggingFace: Filtered \(totalCount) models to \(models.count) text-to-text models (skipped \(nonTextModelsCount) non-text, \(missingArchitectureCount) malformed).")
            }

            await MainActor.run {
                self.huggingFaceModels = models.sorted()
                self.saveHuggingFaceModels()
            }
            logger.logInfo("Successfully fetched \(models.count) HuggingFace models.")

        } catch {
            logger.logError("Error fetching HuggingFace models: \(error.localizedDescription)")
            // Preserve existing cached models on failure
        }
    }
}

/// Errors that can occur during AI text enhancement.
enum EnhancementError: LocalizedError {
    case notConfigured
    case invalidResponse
    case enhancementFailed
    case networkError
    case serverError
    case rateLimitExceeded
    case customError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider not configured"
        case .invalidResponse:
            return "Invalid response from AI"
        case .enhancementFailed:
            return "AI enhancement failed"
        case .networkError:
            return "Network connection failed"
        case .serverError:
            return "Server error occurred"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .customError(let message):
            return message
        }
    }

    var failureReason: String {
        switch self {
        case .notConfigured:
            return "No AI provider API key is configured. Go to Settings and add your API key for the selected AI provider."
        case .invalidResponse:
            return "The AI provider returned an unexpected response format. Please try again or contact support if the issue persists."
        case .enhancementFailed:
            return "The AI service could not process the transcription. The text may be too short or contain unsupported content."
        case .networkError:
            return "Unable to connect to the AI service. Please check your internet connection and try again."
        case .serverError:
            return "The AI provider's server is temporarily unavailable. Please wait a few minutes and try again."
        case .rateLimitExceeded:
            return "You've exceeded the rate limit for the AI service. Please wait a moment before trying again, or upgrade your API plan."
        case .customError(let message):
            return "An error occurred: \(message)"
        }
    }
}
