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
    private static let userDefaults: UserDefaults = UserDefaultsStorage.appPrivate
    private static let storageKey: String = UserDefaultsStorage.Keys.textReplacements

    /// Maximum character length for original or replacement text
    static let maxTextLength = 100

    /// Ordered array of replacements (newest first)
    private(set) var replacements: [Replacement] = []
    
    static func loadAllReplacements() -> [Replacement]? {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Replacement].self, from: data) else {
            return nil
        }
        
        return decoded
    }

    init() {
        loadReplacements()
    }

    private func loadReplacements() {
        replacements = Self.loadAllReplacements() ?? []
        logger.logInfo("Loaded \(self.replacements.count) text replacements")
    }

    private func saveReplacements() {
        guard let data = try? JSONEncoder().encode(replacements) else { return }
        Self.userDefaults.set(data, forKey: Self.storageKey)
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

    // MARK: - Apply Replacements

    /// Applies all stored replacements to the given text (case-insensitive with word boundaries)
    /// - Parameter text: The text to apply replacements to
    /// - Returns: The text with all replacements applied
    static func applyReplacements(to text: String) -> String {
        guard let replacements = loadAllReplacements(), !replacements.isEmpty else {
            return text
        }

        var modifiedText = text

        for replacement in replacements {
            let original = replacement.original
            let replacementText = replacement.replacement

            let usesBoundaries = usesWordBoundaries(for: original)

            if usesBoundaries {
                // Word-boundary regex using Swift native Regex (case-insensitive)
                let escapedOriginal = NSRegularExpression.escapedPattern(for: original)
                if let regex = try? Regex("\\b\(escapedOriginal)\\b").ignoresCase() {
                    modifiedText = modifiedText.replacing(regex, with: replacementText)
                }
            } else {
                // For non-spaced scripts (CJK, Thai, etc.), use simple case-insensitive replacement
                if let regex = try? Regex(NSRegularExpression.escapedPattern(for: original)).ignoresCase() {
                    modifiedText = modifiedText.replacing(regex, with: replacementText)
                }
            }
        }

        return modifiedText
    }

    /// Returns false for languages without spaces (CJK, Thai), true for spaced languages
    private static func usesWordBoundaries(for text: String) -> Bool {
        let nonSpacedScripts: [ClosedRange<UInt32>] = [
            0x3040...0x309F, // Hiragana
            0x30A0...0x30FF, // Katakana
            0x4E00...0x9FFF, // CJK Unified Ideographs
            0xAC00...0xD7AF, // Hangul Syllables
            0x0E00...0x0E7F  // Thai
        ]

        for scalar in text.unicodeScalars {
            for range in nonSpacedScripts {
                if range.contains(scalar.value) {
                    return false
                }
            }
        }

        return true
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
