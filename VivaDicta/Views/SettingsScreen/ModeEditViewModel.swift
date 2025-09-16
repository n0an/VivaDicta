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
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "ModeEditViewModel")
    
    var aiProvider: AIProvider?
    var aiModel: String?
    
    private let aiService: AIService
    
    init(aiService: AIService) {
        self.aiService = aiService
    }
    
    func updateProvider(_ newProvider: AIProvider?) {
        aiProvider = newProvider
        aiModel = newProvider?.defaultModel
        logger.info("Updated provider to: \(newProvider?.rawValue ?? "none")")
    }
    
    func updateModel(_ newModel: String?) {
        aiModel = newModel
        logger.info("Updated model to: \(newModel ?? "none")")
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return aiService.connectedProviders.contains(provider)
    }
    
    func loadFromMode(_ mode: AIEnhanceMode) {
        self.aiProvider = mode.aiProvider
        self.aiModel = mode.aiModel.isEmpty ? mode.aiProvider?.defaultModel : mode.aiModel
    }
    
    func getCurrentProvider() -> AIProvider? {
        return aiProvider
    }
    
    func getCurrentModel() -> String {
        return aiModel ?? aiProvider?.defaultModel ?? ""
    }
}