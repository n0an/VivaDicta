//
//  AIService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.09
//

import SwiftUI
import os

enum AIProvider: String, CaseIterable {
    case groq
    case gemini
    case anthropic
    case openAI
    case openRouter
    case grok
    case elevenLabs
    case deepgram
    
    var baseURL: String {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .grok:
            return "https://api.x.ai/v1/chat/completions"
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .deepgram:
            return "https://api.deepgram.com/v1/listen"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .groq:
            return "qwen/qwen3-32b"
        case .gemini:
            return "gemini-2.0-flash-lite"
        case .anthropic:
            return "claude-sonnet-4-0"
        case .openAI:
            return "gpt-5-mini"
        case .grok:
            return "grok-4"
        case .elevenLabs:
            return "scribe_v1"
        case .deepgram:
            return "whisper-1"
        case .openRouter:
            return "openai/gpt-oss-120b"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .groq:
            return [
                "llama-3.3-70b-versatile",
                "moonshotai/kimi-k2-instruct",
                "qwen/qwen3-32b",
                "meta-llama/llama-4-maverick-17b-128e-instruct",
                "openai/gpt-oss-120b"
            ]
        case .gemini:
            return [
                "gemini-2.5-pro",
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite",
                "gemini-2.0-flash",
                "gemini-2.0-flash-lite"
            ]
        case .anthropic:
            return [
                "claude-opus-4-0",
                "claude-sonnet-4-0",
                "claude-3-7-sonnet-latest",
                "claude-3-5-haiku-latest",
                "claude-3-5-sonnet-latest"
            ]
        case .openAI:
            return [
                "gpt-5",
                "gpt-5-mini",
                "gpt-5-nano",
                "gpt-4.1",
                "gpt-4.1-mini"
            ]
        case .grok:
            return [
                "grok-4",
                "grok-4-heavy",
                "grok-code-fast-1"
            ]
        case .elevenLabs:
            return ["scribe_v1", "scribe_v1_experimental"]
        case .deepgram:
            return ["whisper-1"]
        case .openRouter:
            return []
        }
    }
}

@Observable
class AIService {
    private let logger = Logger(subsystem: "com.antonnovoselov.voiceink", category: "AIService")
    
    var apiKey: String = ""
    var isAPIKeyValid: Bool = false
    
    var selectedProvider: AIProvider {
        didSet {
            userDefaults.set(selectedProvider.rawValue, forKey: Constants.kSelectedAIProvider)
            if let savedKey = userDefaults.string(forKey: Constants.kAPIKeyTemplate + selectedProvider.rawValue) {
                self.apiKey = savedKey
                self.isAPIKeyValid = true
            } else {
                self.apiKey = ""
                self.isAPIKeyValid = false
            }
        }
    }
    
    private var selectedModels: [AIProvider: String] = [:]
    private let userDefaults = UserDefaults.standard
    
    private var openRouterModels: [String] = []
    
    var connectedProviders: [AIProvider] {
        AIProvider.allCases.filter { provider in
            return userDefaults.string(forKey: Constants.kAPIKeyTemplate + provider.rawValue) != nil
        }
    }
    
    var currentModel: String {
        if let selectedModel = selectedModels[selectedProvider],
           !selectedModel.isEmpty,
           availableModels.contains(selectedModel) {
            return selectedModel
        }
        return selectedProvider.defaultModel
    }
    
    var availableModels: [String] {
        if selectedProvider == .openRouter {
            return openRouterModels
        }
        return selectedProvider.availableModels
    }
    
    init() {
        if let savedProviderKey = userDefaults.string(forKey: Constants.kSelectedAIProvider),
           let provider = AIProvider(rawValue: savedProviderKey) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .gemini
        }
        
        if let savedKey = userDefaults.string(forKey: Constants.kAPIKeyTemplate + selectedProvider.rawValue) {
            self.apiKey = savedKey
            self.isAPIKeyValid = true
        }
        
        loadSavedModelSelections()
        loadSavedOpenRouterModels()
    }
    
    private func loadSavedModelSelections() {
        for provider in AIProvider.allCases {
            if let savedModel = userDefaults.string(forKey: provider.rawValue + Constants.kSelectedAIModel),
               !savedModel.isEmpty {
                selectedModels[provider] = savedModel
            }
        }
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: Constants.kOpenRouterModels) as? [String] {
            openRouterModels = savedModels
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: Constants.kOpenRouterModels)
    }
    
    func selectModel(_ model: String) {
        guard !model.isEmpty else { return }
        
        selectedModels[selectedProvider] = model
        userDefaults.set(model, forKey: selectedProvider.rawValue + Constants.kSelectedAIModel)
        
        
//        objectWillChange.send()
//        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    func saveAPIKey(_ key: String) async -> Bool {
        let isValid = await verifyAPIKey(key)
        
        await MainActor.run {
            if isValid {
                self.apiKey = key
                self.isAPIKeyValid = true
                self.userDefaults.set(key, forKey: Constants.kAPIKeyTemplate + self.selectedProvider.rawValue)
//                NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
            } else {
                self.isAPIKeyValid = false
            }
        }
        
        return isValid
    }
    
    func verifyAPIKey(_ key: String) async -> Bool {
        switch selectedProvider {
        case .anthropic:
            return await verifyAnthropicAPIKey(key)
        case .grok:
            return await verifyGrokAPIKey(key)
        case .elevenLabs:
            return await verifyElevenLabsAPIKey(key)
        case .deepgram:
            return await verifyDeepgramAPIKey(key)
        default:
            return await verifyOpenAICompatibleAPIKey(key)
        }
    }
    
    private func verifyOpenAICompatibleAPIKey(_ key: String) async -> Bool {
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let testBody: [String: Any] = [
            "model": currentModel,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        logger.notice("🔑 Verifying API key for \(self.selectedProvider.rawValue, privacy: .public) provider at \(url.absoluteString, privacy: .public)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public): Invalid response")
                return false
            }
            
            let isValid = httpResponse.statusCode == 200
            
            if !isValid {
                // Log the exact API error response
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public) - Status: \(httpResponse.statusCode) - \(exactAPIError, privacy: .public)")
                } else {
                    logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public) - Status: \(httpResponse.statusCode)")
                }
            }
            
            return isValid
            
        } catch {
            logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    private func verifyAnthropicAPIKey(_ key: String) async -> Bool {
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let testBody: [String: Any] = [
            "model": currentModel,
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
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let testBody: [String: Any] = [
            "model": currentModel,
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
    
    func clearAPIKey() {
        
        apiKey = ""
        isAPIKeyValid = false
        userDefaults.removeObject(forKey: Constants.kAPIKeyTemplate + selectedProvider.rawValue)
//        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func fetchOpenRouterModels() async {
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
//                    self.objectWillChange.send()
                }
                return
            }
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                logger.error("Failed to parse OpenRouter models JSON")
                await MainActor.run {
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
//                    self.objectWillChange.send()
                }
                return
            }
            
            let models = dataArray.compactMap { $0["id"] as? String }
            await MainActor.run {
                self.openRouterModels = models.sorted()
                self.saveOpenRouterModels()
                if self.selectedProvider == .openRouter && self.currentModel == self.selectedProvider.defaultModel && !models.isEmpty {
                    self.selectModel(models.sorted().first!)
                }
//                self.objectWillChange.send()
            }
            logger.info("Successfully fetched \(models.count) OpenRouter models.")
            
        } catch {
            logger.error("Error fetching OpenRouter models: \(error.localizedDescription)")
            await MainActor.run {
                self.openRouterModels = []
                self.saveOpenRouterModels()
//                self.objectWillChange.send()
            }
        }

    }
}


