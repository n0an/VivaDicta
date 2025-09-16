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
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AIService")
    
    public var connectedProviders: [AIProvider] = []
    public var openRouterModels: [String] = []
    public var modes: [FlowMode] = []
    
    public var selectedModeName: String {
        didSet {
            self.saveSelectedModeName(selectedModeName)
            self.selectedMode = getMode(name: selectedModeName)
        }
    }
    
    public var selectedMode: FlowMode = FlowMode.defaultMode
    
    private let userDefaults = UserDefaults.standard
    private let baseTimeout: TimeInterval = 30

    
    init() {
        self.selectedModeName = UserDefaults.standard.string(forKey: Constants.kSelectedAIMode) ?? FlowMode.defaultMode.name
        loadModes()
        self.selectedMode = getMode(name: selectedModeName)
        refreshConnectedProviders()
        loadSavedOpenRouterModels()
        
        // Fetch OpenRouter models on startup if API key exists
        Task {
            if connectedProviders.contains(.openRouter) {
                await fetchOpenRouterModels()
            }
        }
    }
    
    public func getMode(name: String) -> FlowMode {
        return modes.first { $0.name == name } ?? FlowMode.defaultMode
    }
    
    public func addMode(_ mode: FlowMode) {
        modes.append(mode)
        saveModes()
        logger.info("Added new mode: \(mode.name)")
    }
    
    public func updateMode(_ mode: FlowMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            saveModes()
            
            // Update selected mode if it's the one being updated
            if selectedMode.id == mode.id {
                selectedMode = mode
            }
            
            logger.info("Updated mode: \(mode.name)")
        }
    }
    
    public func deleteMode(_ mode: FlowMode) {
        guard modes.count > 1 else {
            logger.warning("Cannot delete last mode")
            return
        }
        
        modes.removeAll { $0.name == mode.name }
        
        // If deleted mode was selected, switch to first one
        if selectedMode.name == mode.name {
            selectedModeName = modes[0].name
        }

        saveModes()
        logger.info("Deleted mode: \(mode.name)")
    }

    private func loadModes() {
        if let savedModesData = userDefaults.data(forKey: "AIEnhanceModes"),
           let savedModes = try? JSONDecoder().decode([FlowMode].self, from: savedModesData) {
            modes = savedModes
        } else {
            // Initialize with default mode if no saved modes
            modes = [FlowMode.defaultMode]
        }
        
        logger.info("Loaded \(self.modes.count) AI enhance modes")
    }
    
    private func saveModes() {
        guard let encoded = try? JSONEncoder().encode(modes) else {
            logger.error("Failed to encode AI enhance modes")
            return
        }
        userDefaults.set(encoded, forKey: "AIEnhanceModes")
        logger.info("Saved \(self.modes.count) AI enhance modes")
    }
    
    private func saveSelectedModeName(_ modeName: String) {
        userDefaults.setValue(modeName, forKey: Constants.kSelectedAIMode)
        logger.info("Saved AI enhance mode: \(modeName)")
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: "openRouterModels") as? [String] {
            openRouterModels = savedModels
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: "openRouterModels")
    }
    
    // MARK: - Enhance methods
    public func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()
        
        let modeName = selectedMode.name
        
        do {
            let result = try await makeRequest(text: text)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            return (result, duration, modeName)
        } catch {
            throw error
        }
    }
    
    private func getSystemMessage() -> String {
        return String(format: PromptsTemplates.systemPrompt, selectedMode.prompt)
    }
    
    private func makeRequest(text: String) async throws -> String {
        guard let aiProvider = self.selectedMode.aiProvider,
              let apiKey = self.getAPIKey(for: aiProvider) else {
            throw EnhancementError.notConfigured
        }
        
        guard !text.isEmpty else {
            return ""
        }
        
        let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        let systemMessage = getSystemMessage()
        
        // Log the message being sent to AI enhancement
        logger.notice("AI Enhancement - System Message: \(systemMessage, privacy: .public)")
        logger.notice("AI Enhancement - User Message: \(formattedText, privacy: .public)")
        
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
                let (data, response) = try await URLSession.shared.data(for: request)
                
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

            let requestBody: [String: Any] = [
                "model": selectedMode.aiModel,
                "messages": messages,
                "temperature": selectedMode.aiModel.lowercased().hasPrefix("gpt-5") ? 1.0 : 0.3,
                "stream": false
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

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

            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - API Keys methods
    public func refreshConnectedProviders() {
        connectedProviders = AIProvider.allCases.filter { provider in
            return userDefaults.string(forKey: Constants.kAPIKeyTemplate + provider.rawValue) != nil
        }
    }
    
    public func saveAPIKey(_ key: String, for provider: AIProvider) async -> Bool {
        let isValid = await verifyAPIKey(key, provider: provider)
        
        await MainActor.run {
            if isValid {
                
                // Always save the key for the correct provider
                self.userDefaults.set(key, forKey: Constants.kAPIKeyTemplate + provider.rawValue)
                
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
        return userDefaults.string(forKey: Constants.kAPIKeyTemplate + provider.rawValue)
    }
    
    private func verifyAPIKey(_ key: String, provider: AIProvider) async -> Bool {
        switch provider {
        case .anthropic:
            return await verifyAnthropicAPIKey(key)
        case .grok:
            return await verifyGrokAPIKey(key)
        case .elevenLabs:
            return await verifyElevenLabsAPIKey(key)
        case .deepgram:
            return await verifyDeepgramAPIKey(key)
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
        
        logger.notice("🔑 Verifying API key for \(provider.rawValue, privacy: .public) provider at \(url.absoluteString, privacy: .public)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.notice("🔑 API key verification failed for \(provider.rawValue, privacy: .public): Invalid response")
                return false
            }
            
            let isValid = httpResponse.statusCode == 200
            
            if !isValid {
                // Log the exact API error response
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.notice("🔑 API key verification failed for \(provider.rawValue, privacy: .public) - Status: \(httpResponse.statusCode) - \(exactAPIError, privacy: .public)")
                } else {
                    logger.notice("🔑 API key verification failed for \(provider.rawValue, privacy: .public) - Status: \(httpResponse.statusCode)")
                }
            }
            
            return isValid
            
        } catch {
            logger.notice("🔑 API key verification failed for \(provider.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                logger.info("ElevenLabs verification response: \(body)")
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
            logger.error("Deepgram API key verification failed: \(error.localizedDescription)")
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
        
        logger.notice("🔑 Verifying Grok API key at \(url.absoluteString, privacy: .public)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.notice("🔑 Grok API key verification failed: Invalid response")
                return false
            }
            
            let isValid = httpResponse.statusCode == 200
            
            if !isValid {
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.notice("🔑 Grok API key verification failed - Status: \(httpResponse.statusCode) - \(exactAPIError, privacy: .public)")
                } else {
                    logger.notice("🔑 Grok API key verification failed - Status: \(httpResponse.statusCode)")
                }
            }
            
            return isValid
            
        } catch {
            logger.notice("🔑 Grok API key verification failed: \(error.localizedDescription, privacy: .public)")
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
                logger.error("Failed to fetch OpenRouter models: Invalid HTTP response")
                await MainActor.run { 
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                }
                return
            }
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any], 
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.error("Failed to parse OpenRouter models JSON")
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
            logger.info("Successfully fetched \(models.count) OpenRouter models.")
            
        } catch {
            logger.error("Error fetching OpenRouter models: \(error.localizedDescription)")
            await MainActor.run { 
                self.openRouterModels = []
                self.saveOpenRouterModels()
            }
        }
    }
}

enum EnhancementError: Error {
    case notConfigured
    case invalidResponse
    case enhancementFailed
    case networkError
    case serverError
    case rateLimitExceeded
    case customError(String)
}

extension EnhancementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider not configured. Please check your API key."
        case .invalidResponse:
            return "Invalid response from AI provider."
        case .enhancementFailed:
            return "AI enhancement failed to process the text."
        case .networkError:
            return "Network connection failed. Check your internet."
        case .serverError:
            return "The AI provider's server encountered an error. Please try again later."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .customError(let message):
            return message
        }
    }
}
