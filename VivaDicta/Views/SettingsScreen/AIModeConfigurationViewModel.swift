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
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AIModeConfigurationViewModel")
    private let userDefaults = UserDefaults.standard
    
    var aiProvider: AIProvider?
    var aiModel: String?
    
    private var mode: AIEnhanceMode
    private let aiService: AIService
    
    init(mode: AIEnhanceMode, aiService: AIService) {
        self.mode = mode
        self.aiService = aiService
        
        let filledMode = aiService.getMode(name: mode.name)
        self.aiProvider = filledMode.aiProvider
        self.aiModel = filledMode.aiModel
        
    }
    
    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider
        aiModel = newProvider?.defaultModel
        saveConfiguration()
    }
    
    func updateModel(_ newModel: String?) {
        aiModel = newModel
        saveConfiguration()
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return aiService.connectedProviders.contains(provider)
    }
    
    private func saveConfiguration() {
        mode.aiProvider = aiProvider
        mode.aiModel = aiModel ?? aiProvider?.defaultModel ?? ""
        
        aiService.saveMode(mode)
        
        logger.info("Saved AI configuration for mode '\(self.mode.name)': provider=\(self.aiProvider?.rawValue ?? "none"), model=\(self.aiModel ?? "none")")
    }
}
