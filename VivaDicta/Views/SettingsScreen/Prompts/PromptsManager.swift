//
//  PromptsManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import Foundation
import SwiftUI
import os

@Observable
class PromptsManager {
    private let logger = Logger(category: .promptsManager)
    // User prompts need to be shared with keyboard extension (used in Flow Modes)
    private let userDefaults = UserDefaultsStorage.shared
    private let userPromptsKey = "UserPrompts"
    
    var userPrompts: [UserPrompt] = []
    
    init() {
        loadUserPrompts()
    }
    
    // MARK: - Public Methods
    
    func addPrompt(_ prompt: UserPrompt) {
        userPrompts.append(prompt)
        saveUserPrompts()
        logger.logInfo("Added new prompt: \(prompt.title)")
    }
    
    func updatePrompt(_ prompt: UserPrompt) {
        if let index = userPrompts.firstIndex(where: { $0.id == prompt.id }) {
            userPrompts[index] = prompt
            saveUserPrompts()
            logger.logInfo("Updated prompt: \(prompt.title)")
        }
    }
    
    func deletePrompt(_ prompt: UserPrompt) {
        userPrompts.removeAll { $0.id == prompt.id }
        saveUserPrompts()
        logger.logInfo("Deleted prompt: \(prompt.title)")
    }
    
    
    // MARK: - Private Methods
    private func loadUserPrompts() {
        guard let data = userDefaults.data(forKey: userPromptsKey),
              let prompts = try? JSONDecoder().decode([UserPrompt].self, from: data) else {
            userPrompts = []
            return
        }
        userPrompts = prompts
        logger.logInfo("Loaded \(prompts.count) user prompts")
    }
    
    private func saveUserPrompts() {
        guard let data = try? JSONEncoder().encode(userPrompts) else {
            logger.logError("Failed to encode user prompts")
            return
        }
        userDefaults.set(data, forKey: userPromptsKey)
        logger.logInfo("Saved \(self.userPrompts.count) user prompts")
    }
    
}
