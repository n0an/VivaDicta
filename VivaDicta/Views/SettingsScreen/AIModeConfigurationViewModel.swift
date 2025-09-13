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
        
//        let config = Self.getConfiguration(for: mode)
//        self.aiProvider = config.provider
//        self.aiModel = config.model
    }
    
    func updateProvider(_ newProvider: AIProvider?) {
//        self.mode.aiProvider = newProvider
        aiProvider = newProvider
        
        aiModel = newProvider?.defaultModel
        
//        if let provider = newProvider {
//            aiModel = provider.defaultModel
//        } else {
//            aiModel = nil
//        }
        saveConfiguration()
    }
    
    func updateModel(_ newModel: String?) {
//        mode.aiModel = newModel ?? ""
        aiModel = newModel
        saveConfiguration()
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return aiService.connectedProviders.contains(provider)
    }
    
    private func saveConfiguration() {
        //        let providerKey = "aiMode_\(mode.name)_provider"
        //        let modelKey = "aiMode_\(mode.name)_model"
        
        //        if let provider = aiProvider {
        //            userDefaults.set(provider.rawValue, forKey: providerKey)
        //        } else {
        //            userDefaults.removeObject(forKey: providerKey)
        //        }
        //
        //        if let model = aiModel {
        //            userDefaults.set(model, forKey: modelKey)
        //        } else {
        //            userDefaults.removeObject(forKey: modelKey)
        //        }
        
        mode.aiProvider = aiProvider
        mode.aiModel = aiModel ?? aiProvider?.defaultModel ?? ""
        
        aiService.saveMode(mode)
        
        //        aiService.selectedMode = mode
        
        logger.info("Saved AI configuration for mode '\(self.mode.name)': provider=\(self.aiProvider?.rawValue ?? "none"), model=\(self.aiModel ?? "none")")
    }
    
//    private static func getConfiguration(for mode: AIEnhanceMode) -> (provider: AIProvider?, model: String?) {
//        let userDefaults = UserDefaults.standard
//        
//        let providerKey = "aiMode_\(mode.name)_provider"
//        let provider: AIProvider?
//        if let savedProviderRaw = userDefaults.string(forKey: providerKey),
//           let savedProvider = AIProvider(rawValue: savedProviderRaw) {
//            provider = savedProvider
//        } else {
//            provider = nil
//        }
//        
//        let modelKey = "aiMode_\(mode.name)_model"
//        let model: String?
//        if let savedModel = userDefaults.string(forKey: modelKey),
//           !savedModel.isEmpty {
//            model = savedModel
//        } else {
//            model = nil
//        }
//        
//        return (provider: provider, model: model)
//    }
}
