//
//  ReplacementsService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import Foundation
import SwiftUI
import os

@Observable
class ReplacementsService {
    private let logger = Logger(category: .customVocabulary)
    private let userDefaults: UserDefaults
    private let storageKey: String

    /// Maximum character length for original or replacement text
    static let maxTextLength = 100

    /// Ordered array of replacements (newest first)
    private(set) var replacements: [Replacement] = []

    init(userDefaults: UserDefaults = UserDefaultsStorage.appPrivate,
         storageKey: String = UserDefaultsStorage.Keys.textReplacements) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        loadReplacements()
    }

    private func loadReplacements() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Replacement].self, from: data) else {
            replacements = []
            return
        }
        replacements = decoded
        logger.logInfo("Loaded \(self.replacements.count) text replacements")
    }

    private func saveReplacements() {
        guard let data = try? JSONEncoder().encode(replacements) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func addReplacement(original: String, replacement: String) {
        var trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOriginal.isEmpty, !trimmedReplacement.isEmpty else { return }

        // Truncate if too long
        if trimmedOriginal.count > Self.maxTextLength {
            trimmedOriginal = String(trimmedOriginal.prefix(Self.maxTextLength))
        }
        if trimmedReplacement.count > Self.maxTextLength {
            trimmedReplacement = String(trimmedReplacement.prefix(Self.maxTextLength))
        }

        // Check for duplicate original (case-insensitive)
        let isDuplicate = replacements.contains {
            $0.original.lowercased() == trimmedOriginal.lowercased()
        }
        guard !isDuplicate else {
            logger.logWarning("Replacement already exists for: \(trimmedOriginal)")
            return
        }

        let newReplacement = Replacement(original: trimmedOriginal, replacement: trimmedReplacement)
        replacements.insert(newReplacement, at: 0)
        saveReplacements()
        logger.logInfo("Added replacement: \(trimmedOriginal) -> \(trimmedReplacement)")
    }

    func updateReplacement(_ oldReplacement: Replacement, original: String, replacement: String) {
        var trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOriginal.isEmpty, !trimmedReplacement.isEmpty else { return }

        // Truncate if too long
        if trimmedOriginal.count > Self.maxTextLength {
            trimmedOriginal = String(trimmedOriginal.prefix(Self.maxTextLength))
        }
        if trimmedReplacement.count > Self.maxTextLength {
            trimmedReplacement = String(trimmedReplacement.prefix(Self.maxTextLength))
        }

        // Check for duplicate original (case-insensitive), excluding the one being edited
        let isDuplicate = replacements.contains {
            $0.original.lowercased() == trimmedOriginal.lowercased() && $0.id != oldReplacement.id
        }
        guard !isDuplicate else {
            logger.logWarning("Replacement already exists for: \(trimmedOriginal)")
            return
        }

        if let index = replacements.firstIndex(where: { $0.id == oldReplacement.id }) {
            replacements[index] = Replacement(
                id: oldReplacement.id,
                original: trimmedOriginal,
                replacement: trimmedReplacement
            )
            saveReplacements()
            logger.logInfo("Updated replacement: \(trimmedOriginal) -> \(trimmedReplacement)")
        }
    }

    func deleteReplacement(_ replacement: Replacement) {
        replacements.removeAll { $0.id == replacement.id }
        saveReplacements()
        logger.logInfo("Deleted replacement: \(replacement.original)")
    }

    func deleteReplacements(at offsets: IndexSet) {
        replacements.remove(atOffsets: offsets)
        saveReplacements()
        logger.logInfo("Deleted \(offsets.count) replacements")
    }
}

// MARK: - Replacement Model

struct Replacement: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    let original: String
    let replacement: String

    init(id: UUID = UUID(), original: String, replacement: String) {
        self.id = id
        self.original = original
        self.replacement = replacement
    }
}
