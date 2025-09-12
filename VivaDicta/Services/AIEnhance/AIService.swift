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
    
    var connectedProviders: [AIProvider] = []
    
    var selectedMode: AIEnhanceMode {
        didSet {
            saveMode(selectedMode)
        }
    }
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        
        // Load saved mode
        if let savedModeData = userDefaults.data(forKey: Constants.kSelectedAIMode),
           let savedMode = try? JSONDecoder().decode(AIEnhanceMode.self, from: savedModeData) {
            self.selectedMode = savedMode
        } else {
            self.selectedMode = AIEnhanceMode.predefinedModes[0]
        }
        
        refreshConnectedProviders()
    }
    
    private func refreshConnectedProviders() {
        connectedProviders = AIProvider.allCases.filter { provider in
            return userDefaults.string(forKey: Constants.kAPIKeyTemplate + provider.rawValue) != nil
        }
    }
    
    func saveMode(_ mode: AIEnhanceMode) {
        if let encoded = try? JSONEncoder().encode(mode) {
            userDefaults.set(encoded, forKey: Constants.kSelectedAIMode)
            logger.info("Saved AI enhance mode: \(mode.name)")
        } else {
            logger.error("Failed to encode AI enhance mode: \(mode.name)")
        }
    }
    
    func saveAPIKey(_ key: String, for provider: AIProvider) async -> Bool {
        let isValid = await verifyAPIKey(key, provider: provider)
        
        await MainActor.run {
            if isValid {
                
                // Always save the key for the correct provider
                self.userDefaults.set(key, forKey: Constants.kAPIKeyTemplate + provider.rawValue)
                
                // Refresh connected providers to trigger UI update
                self.refreshConnectedProviders()
                
            }
        }
        
        return isValid
    }
    
    func verifyAPIKey(_ key: String, provider: AIProvider) async -> Bool {
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
    
    
}


