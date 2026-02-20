//
//  ReplacementsService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import Foundation
import SwiftUI
import SwiftData
import os

/// Provides word replacement functionality backed by SwiftData.
/// The static `applyReplacements(to:)` method is used in the transcription pipeline.
/// CRUD operations happen directly via `ModelContext` in views.
enum ReplacementsService {
    /// Maximum character length for original or replacement text
    static let maxTextLength = 100

    /// Set once at app startup to enable SwiftData-backed replacement lookups
    static var modelContainer: ModelContainer?

    // MARK: - Apply Replacements

    /// Applies all enabled replacements from SwiftData to the given text
    static func applyReplacements(to text: String) -> String {
        guard let container = modelContainer else { return text }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WordReplacement>(
            predicate: #Predicate { $0.isEnabled }
        )

        guard let replacements = try? context.fetch(descriptor), !replacements.isEmpty else {
            return text
        }

        var modifiedText = text

        for replacement in replacements {
            let originalGroup = replacement.originalText
            let replacementText = replacement.replacementText

            // Split comma-separated originals at apply time
            let variants = originalGroup
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for original in variants {
                let usesBoundaries = usesWordBoundaries(for: original)

                if usesBoundaries {
                    let escapedOriginal = NSRegularExpression.escapedPattern(for: original)
                    if let regex = try? Regex("\\b\(escapedOriginal)\\b").ignoresCase() {
                        modifiedText = modifiedText.replacing(regex, with: replacementText)
                    }
                } else {
                    if let regex = try? Regex(NSRegularExpression.escapedPattern(for: original)).ignoresCase() {
                        modifiedText = modifiedText.replacing(regex, with: replacementText)
                    }
                }
            }
        }

        return modifiedText
    }

    /// Returns false for languages without spaces (CJK, Thai), true for spaced languages
    static func usesWordBoundaries(for text: String) -> Bool {
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

// MARK: - Legacy Replacement Model (kept for migration decoding and tests)

struct Replacement: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    let original: String
    let replacement: String

    init(id: UUID = UUID(), original: String, replacement: String) {
        self.id = id
        self.original = original
        self.replacement = replacement
    }
}
