//
//  PromptsManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import Foundation
import SwiftUI
import os

/// Manager for user-defined AI enhancement prompts.
///
/// `PromptsManager` handles CRUD operations for ``UserPrompt`` instances, which define
/// the instructions given to AI providers when enhancing transcriptions.
///
/// ## Overview
///
/// The manager provides:
/// - Loading and saving prompts to shared UserDefaults
/// - Duplicate name detection with normalization
/// - Prompt duplication with automatic name generation
///
/// ## Persistence
///
/// Prompts are stored in the shared App Group UserDefaults, making them accessible
/// to both the main app and the keyboard extension for Flow Mode functionality.
///
/// ## Usage
///
/// ```swift
/// let manager = PromptsManager()
///
/// // Add a new prompt
/// let prompt = UserPrompt(title: "Email", promptInstructions: "Format as professional email")
/// manager.addPrompt(prompt)
///
/// // Duplicate an existing prompt
/// manager.duplicatePrompt(existingPrompt)  // Creates "Email 1"
/// ```
@Observable
class PromptsManager {
    private let logger = Logger(category: .promptsManager)
    // User prompts need to be shared with keyboard extension (used in Flow Modes)
    private let userDefaults: UserDefaults
    private let userPromptsKey: String

    /// All user-defined prompts.
    var userPrompts: [UserPrompt] = []

    /// Creates a PromptsManager with the specified storage.
    ///
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use for persistence.
    ///   - storageKey: The key under which prompts are stored.
    init(userDefaults: UserDefaults = UserDefaultsStorage.shared,
         storageKey: String = "UserPrompts") {
        self.userDefaults = userDefaults
        self.userPromptsKey = storageKey
        loadUserPrompts()
    }
    
    // MARK: - Public Methods

    /// Checks if a prompt name already exists.
    ///
    /// - Parameters:
    ///   - name: The name to check.
    ///   - excludingId: Optional ID to exclude (for editing existing prompts).
    /// - Returns: `true` if the name is already used by another prompt.
    func isPromptNameDuplicate(_ name: String, excludingId: UUID? = nil) -> Bool {
        let normalizedName = normalizeForComparison(name)
        return userPrompts.contains { prompt in
            normalizeForComparison(prompt.title) == normalizedName && prompt.id != excludingId
        }
    }

    /// Adds a new prompt to the collection.
    ///
    /// - Parameter prompt: The prompt to add.
    func addPrompt(_ prompt: UserPrompt) {
        userPrompts.append(prompt)
        saveUserPrompts()
        logger.logInfo("Added new prompt: \(prompt.title)")
    }
    
    /// Updates an existing prompt.
    ///
    /// - Parameter prompt: The prompt with updated values (matched by ID).
    func updatePrompt(_ prompt: UserPrompt) {
        if let index = userPrompts.firstIndex(where: { $0.id == prompt.id }) {
            userPrompts[index] = prompt
            saveUserPrompts()
            logger.logInfo("Updated prompt: \(prompt.title)")
        }
    }
    
    /// Deletes a prompt from the collection.
    ///
    /// - Parameter prompt: The prompt to delete.
    func deletePrompt(_ prompt: UserPrompt) {
        userPrompts.removeAll { $0.id == prompt.id }
        saveUserPrompts()
        logger.logInfo("Deleted prompt: \(prompt.title)")
    }

    /// Creates a duplicate of a prompt with a numbered suffix.
    ///
    /// - Parameter prompt: The prompt to duplicate.
    func duplicatePrompt(_ prompt: UserPrompt) {
        let newName = generateDuplicateName(for: prompt.title)
        let newPrompt = UserPrompt(
            title: newName,
            promptInstructions: prompt.promptInstructions
        )
        addPrompt(newPrompt)
    }

    /// Generates a unique name for duplicating a prompt
    /// "Email" → "Email 1", "Email 1" → "Email 2", etc.
    func generateDuplicateName(for originalName: String) -> String {
        let trimmedName = originalName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract base name and current number if exists
        // Pattern: "Name" or "Name N" where N is a number
        let pattern = /^(.+?)\s+(\d+)$/
        let baseName: String
        if let match = trimmedName.wholeMatch(of: pattern) {
            baseName = String(match.1)
        } else {
            baseName = trimmedName
        }

        // Find the highest number used for this base name
        // Use normalized comparison (whitespace-insensitive)
        var highestNumber = 0
        let normalizedBaseName = normalizeForComparison(baseName)
        let numberPattern = /^(.+?)\s+(\d+)$/

        for prompt in userPrompts {
            let promptTitle = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizeForComparison(promptTitle) == normalizedBaseName {
                // Exact match with base name means at least 1 exists
                highestNumber = max(highestNumber, 0)
            } else if let match = promptTitle.wholeMatch(of: numberPattern),
                      normalizeForComparison(String(match.1)) == normalizedBaseName,
                      let num = Int(match.2) {
                highestNumber = max(highestNumber, num)
            }
        }

        return "\(baseName) \(highestNumber + 1)"
    }

    // MARK: - Private Methods

    /// Normalizes a name for comparison by removing all whitespace and lowercasing
    /// "my prompt" and "my  prompt" will both become "myprompt"
    private func normalizeForComparison(_ name: String) -> String {
        name.split(separator: /\s+/).joined().lowercased()
    }

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
