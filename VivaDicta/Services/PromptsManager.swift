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
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "PromptsManager")
    private let userDefaults = UserDefaults.standard
    private let userPromptsKey = "UserPrompts"
    
    var userPrompts: [UserPrompt] = []
    var activePrompt: UserPrompt? {
        didSet {
            if let activePrompt = activePrompt {
                saveActivePromptID(activePrompt.id)
            }
        }
    }
    
    init() {
        loadUserPrompts()
        loadActivePrompt()
    }
    
    // MARK: - Public Methods
    
    func addPrompt(_ prompt: UserPrompt) {
        userPrompts.append(prompt)
        saveUserPrompts()
        logger.info("Added new prompt: \(prompt.title)")
    }
    
    func updatePrompt(_ prompt: UserPrompt) {
        if let index = userPrompts.firstIndex(where: { $0.id == prompt.id }) {
            userPrompts[index] = prompt
            saveUserPrompts()
            
            // Update active prompt if it's the one being updated
            if activePrompt?.id == prompt.id {
                activePrompt = prompt
            }
            
            logger.info("Updated prompt: \(prompt.title)")
        }
    }
    
    func deletePrompt(_ prompt: UserPrompt) {
        userPrompts.removeAll { $0.id == prompt.id }
        
        // Clear active prompt if deleted
        if activePrompt?.id == prompt.id {
            activePrompt = nil
        }
        
        saveUserPrompts()
        logger.info("Deleted prompt: \(prompt.title)")
    }
    
    func setActivePrompt(_ prompt: UserPrompt?) {
        // Deactivate current active prompt
        if let currentActive = activePrompt,
           let index = userPrompts.firstIndex(where: { $0.id == currentActive.id }) {
            var updatedPrompt = currentActive
            updatedPrompt.isActive = false
            userPrompts[index] = updatedPrompt
        }
        
        // Activate new prompt
        if let newActive = prompt,
           let index = userPrompts.firstIndex(where: { $0.id == newActive.id }) {
            var updatedPrompt = newActive
            updatedPrompt.isActive = true
            userPrompts[index] = updatedPrompt
            activePrompt = updatedPrompt
        } else {
            activePrompt = nil
        }
        
        saveUserPrompts()
        logger.info("Set active prompt: \(prompt?.title ?? "None")")
    }
    
    func createPromptFromTemplate(_ template: PromptsTemplates, title: String, description: String) -> UserPrompt {
        return UserPrompt(
            title: title.isEmpty ? template.defaultTitle : title,
            description: description.isEmpty ? template.description : description,
            promptInstructions: template.prompt,
            templateType: template
        )
    }
    
    // MARK: - Private Methods
    
    private func loadUserPrompts() {
        guard let data = userDefaults.data(forKey: userPromptsKey),
              let prompts = try? JSONDecoder().decode([UserPrompt].self, from: data) else {
            userPrompts = []
            return
        }
        userPrompts = prompts
        logger.info("Loaded \(prompts.count) user prompts")
    }
    
    private func saveUserPrompts() {
        guard let data = try? JSONEncoder().encode(userPrompts) else {
            logger.error("Failed to encode user prompts")
            return
        }
        userDefaults.set(data, forKey: userPromptsKey)
        logger.info("Saved \(self.userPrompts.count) user prompts")
    }
    
    private func loadActivePrompt() {
        guard let activePromptID = userDefaults.string(forKey: "ActivePromptID"),
              let uuid = UUID(uuidString: activePromptID),
              let prompt = userPrompts.first(where: { $0.id == uuid }) else {
            return
        }
        activePrompt = prompt
    }
    
    private func saveActivePromptID(_ id: UUID) {
        userDefaults.set(id.uuidString, forKey: "ActivePromptID")
    }
}