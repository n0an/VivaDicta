//
//  AIModeConfigurationViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI
import os

@Observable
class AIModeConfigurationViewModel {
    private let logger = Logger(subsystem: "com.antonnovoselov.voiceink", category: "AIModeConfigurationViewModel")
    private let userDefaults = UserDefaults.standard
    
    var aiProvider: AIProvider?
    var aiModel: String?
    
    private let mode: AIEnhanceMode
    
    init(mode: AIEnhanceMode) {
        self.mode = mode
        
        let config = Self.getConfiguration(for: mode)
        self.aiProvider = config.provider
        self.aiModel = config.model
    }
    
    func saveConfiguration() {
        let providerKey = "aiMode_\(mode.name)_provider"
        let modelKey = "aiMode_\(mode.name)_model"
        
        if let provider = aiProvider {
            userDefaults.set(provider.rawValue, forKey: providerKey)
        } else {
            userDefaults.removeObject(forKey: providerKey)
        }
        
        if let model = aiModel {
            userDefaults.set(model, forKey: modelKey)
        } else {
            userDefaults.removeObject(forKey: modelKey)
        }
        
        logger.info("Saved AI configuration for mode '\(self.mode.name)': provider=\(self.aiProvider?.rawValue ?? "none"), model=\(self.aiModel ?? "none")")
    }
    
    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider
        // Reset model when provider changes
        if let provider = newProvider {
            aiModel = provider.defaultModel
        } else {
            aiModel = nil
        }
        saveConfiguration()
    }
    
    func updateModel(_ newModel: String?) {
        aiModel = newModel
        saveConfiguration()
    }
    
    static func getConfiguration(for mode: AIEnhanceMode) -> (provider: AIProvider?, model: String?) {
        let userDefaults = UserDefaults.standard
        
        let providerKey = "aiMode_\(mode.name)_provider"
        let provider: AIProvider?
        if let savedProviderRaw = userDefaults.string(forKey: providerKey),
           let savedProvider = AIProvider(rawValue: savedProviderRaw) {
            provider = savedProvider
        } else {
            provider = nil
        }
        
        let modelKey = "aiMode_\(mode.name)_model"
        let model: String?
        if let savedModel = userDefaults.string(forKey: modelKey),
           !savedModel.isEmpty {
            model = savedModel
        } else {
            model = nil
        }
        
        return (provider: provider, model: model)
    }
}