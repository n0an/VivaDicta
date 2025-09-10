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
            return userDefaults.string(forKey: "\(provider.rawValue)APIKey") != nil
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
        if let savedProvider = userDefaults.string(forKey: "selectedAIProvider"),
           let provider = AIProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .gemini
        }
        
        if let savedKey = userDefaults.string(forKey: "\(selectedProvider.rawValue)APIKey") {
            self.apiKey = savedKey
            self.isAPIKeyValid = true
        }
        
        loadSavedModelSelections()
        loadSavedOpenRouterModels()
    }
    
    private func loadSavedModelSelections() {
        for provider in AIProvider.allCases {
            let key = "\(provider.rawValue)SelectedModel"
            if let savedModel = userDefaults.string(forKey: key), !savedModel.isEmpty {
                selectedModels[provider] = savedModel
            }
        }
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: "openRouterModels") as? [String] {
            openRouterModels = savedModels
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: "openRouterModels")
    }
    
    func selectModel(_ model: String) {
        guard !model.isEmpty else { return }
        
        selectedModels[selectedProvider] = model
        let key = "\(selectedProvider.rawValue)SelectedModel"
        userDefaults.set(model, forKey: key)
        
        
//        objectWillChange.send()
//        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    func saveAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        verifyAPIKey(key) { [weak self] isValid in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if isValid {
                    self.apiKey = key
                    self.isAPIKeyValid = true
                    self.userDefaults.set(key, forKey: "\(self.selectedProvider.rawValue)APIKey")
//                    NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                } else {
                    self.isAPIKeyValid = false
                }
                completion(isValid)
            }
        }
    }
    
    func verifyAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        switch selectedProvider {
        case .anthropic:
            verifyAnthropicAPIKey(key, completion: completion)
        case .elevenLabs:
            verifyElevenLabsAPIKey(key, completion: completion)
        case .deepgram:
            verifyDeepgramAPIKey(key, completion: completion)
        default:
            verifyOpenAICompatibleAPIKey(key, completion: completion)
        }
    }
    
    private func verifyOpenAICompatibleAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let isValid = httpResponse.statusCode == 200
                
                if !isValid {
                    // Log the exact API error response
                    if let data = data, let exactAPIError = String(data: data, encoding: .utf8) {
                        self.logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public) - Status: \(httpResponse.statusCode) - \(exactAPIError, privacy: .public)")
                    } else {
                        self.logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public) - Status: \(httpResponse.statusCode)")
                    }
                }
                
                completion(isValid)
            } else {
                self.logger.notice("🔑 API key verification failed for \(self.selectedProvider.rawValue, privacy: .public): Invalid response")
                completion(false)
            }
        }
        .resume()
    }
    
    private func verifyAnthropicAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }
        .resume()
    }
    
    private func verifyElevenLabsAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://api.elevenlabs.io/v1/user")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "xi-api-key")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200

            if let data = data, let body = String(data: data, encoding: .utf8) {
                self.logger.info("ElevenLabs verification response: \(body)")
            }

            completion(isValid)
        }
        .resume()
    }
    
    private func verifyDeepgramAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://api.deepgram.com/v1/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Token \(key)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logger.error("Deepgram API key verification failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }
        .resume()
    }
    
    func clearAPIKey() {
        
        apiKey = ""
        isAPIKeyValid = false
        userDefaults.removeObject(forKey: "\(selectedProvider.rawValue)APIKey")
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
                self.saveOpenRouterModels() // Save to UserDefaults
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


