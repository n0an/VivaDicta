//
//  AIService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.09
//

import SwiftUI
import os

@Observable
class AIService {
    private let logger = Logger(category: .aiService)

    public var connectedProviders: [AIProvider] = []
    public var openRouterModels: [String] = []
    public var modes: [VivaMode] = []

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
        loadModes()
        self.selectedMode = getMode(name: selectedModeName)
        loadSavedOpenRouterModels()

        // Refresh connected providers on main actor (needed for Apple availability check)
        Task { @MainActor in
            refreshConnectedProviders()
            if connectedProviders.contains(.openRouter) {
                await fetchOpenRouterModels()
            }
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

        modes.removeAll { $0.name == mode.name }

        // If deleted mode was selected, switch to first one
        if selectedMode.name == mode.name {
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
    
    // MARK: - Configuration validation
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
    public func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()

        let promptName = selectedMode.userPrompt?.title

        do {
            let result = try await makeRequest(text: text)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            return (result, duration, promptName)
        } catch {
            throw error
        }
    }

    // TODO: Add method to generate tags/keywords for transcriptions
    // public func generateTags(for text: String, maxTags: Int = 10) async throws -> [String] {
    //     // Use LLM to analyze text and extract key topics, themes, entities
    //     // Return array of meaningful tags for Spotlight indexing
    //     // Consider using a specific prompt optimized for tag extraction
    // }
    
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
                logger.logNotice("AI Enhancement - Using Apple Foundation Model")
                logger.logNotice("AI Enhancement - Prompt Prefix: \(promptPrefix)")
                return try await appleFoundationModelService.enhance(text, instructions: instructions, promptPrefix: promptPrefix)
            } else {
                throw EnhancementError.notConfigured
            }
        }

        // Cloud providers - compute system message only when needed
        let systemMessage = getSystemMessage()

        // Cloud providers require API key
        guard let apiKey = self.getAPIKey(for: aiProvider) else {
            throw EnhancementError.notConfigured
        }

        let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"

        logger.logNotice("AI Enhancement - System Message: \(systemMessage)")
        logger.logNotice("AI Enhancement - User Message: \(formattedText)")

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
        if let customVocabularyWords = UserDefaultsStorage.appPrivate.stringArray(forKey: UserDefaultsStorage.Keys.customVocabularyWords), !customVocabularyWords.isEmpty {
            let vocabularyString = customVocabularyWords.joined(separator: ", ")
            customVocabularySection = "\n\n<CUSTOM_VOCABULARY>Important Vocabulary: \(vocabularyString)\n</CUSTOM_VOCABULARY>"
        }

        let promptInstructions = selectedMode.userPrompt?.promptInstructions ?? ""
        return PromptsTemplates.systemPrompt(with: promptInstructions) + customVocabularySection
    }

    // MARK: - Foundation Model Prompts (Apple)

    /// Returns instructions for LanguageModelSession (role + core rules + vocabulary)
    /// Used with LanguageModelSession(instructions:)
    private func getFoundationModelInstructions() -> String {
        var customVocabulary: String? = nil
        if let words = UserDefaultsStorage.appPrivate.stringArray(forKey: UserDefaultsStorage.Keys.customVocabularyWords),
           !words.isEmpty {
            customVocabulary = words.joined(separator: ", ")
        }
        return PromptsTemplates.foundationModelInstructions(customVocabulary: customVocabulary)
    }

    /// Returns prompt prefix for prewarm (user prompt instructions only)
    /// Used with session.prewarm(promptPrefix:)
    private func getFoundationModelPromptPrefix() -> String {
        let promptInstructions = selectedMode.userPrompt?.promptInstructions ?? ""
        return PromptsTemplates.foundationModelPromptPrefix(promptInstructions: promptInstructions)
    }
    
    
    // MARK: - API Keys methods
    @MainActor
    public func refreshConnectedProviders() {
        var providers: [AIProvider] = []

        // Add Apple provider if Foundation Models are available (no API key needed)
        if AppleFoundationModelAvailability.isAvailable {
            providers.append(.apple)
        }

        // Add cloud providers that have API keys configured
        providers += AIProvider.allCases.filter { provider in
            provider.requiresAPIKey &&
            userDefaults.string(forKey: AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue) != nil
        }

        connectedProviders = providers
    }
    
    public func saveAPIKey(_ key: String, for provider: AIProvider) async -> Bool {
        let isValid = await verifyAPIKey(key, provider: provider)
        
        await MainActor.run {
            if isValid {
                self.userDefaults.set(key, forKey: AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue)
                
                // Refresh connected providers to trigger UI update
                self.refreshConnectedProviders()
            }
        }
        
        // Fetch OpenRouter models if this is an OpenRouter key
        if isValid && provider == .openRouter {
            await fetchOpenRouterModels()
        }
        
        return isValid
    }
    
    private func getAPIKey(for provider: AIProvider) -> String? {
        return userDefaults.string(forKey: AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue)
    }
    
    private func verifyAPIKey(_ key: String, provider: AIProvider) async -> Bool {
        switch provider {
        case .apple:
            // Apple doesn't require API key verification
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
    
    // MARK: - OpenRouter Models methods
    public func getAvailableModels(for provider: AIProvider) -> [String] {
        if provider == .openRouter {
            return openRouterModels
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
                await MainActor.run {
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                }
                return
            }

            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.logError("Failed to parse OpenRouter models JSON")
                await MainActor.run {
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                }
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
            await MainActor.run {
                self.openRouterModels = []
                self.saveOpenRouterModels()
            }
        }
    }
}

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
