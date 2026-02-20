//
//  CustomVocabulary.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.08
//

import Foundation
import SwiftData

enum CustomVocabulary {
    /// Set once at app startup to enable SwiftData-backed vocabulary lookups
    static var modelContainer: ModelContainer?

    /// Retrieves custom vocabulary terms from SwiftData, deduplicated and optionally limited.
    /// - Parameter maxTerms: Optional maximum number of terms to return. If nil, returns all terms.
    /// - Returns: Array of unique vocabulary terms, preserving original order. Returns empty array if spelling corrections are disabled.
    static func getTerms(maxTerms: Int? = nil) -> [String] {
        // Check if spelling corrections are enabled
        let isEnabled = UserDefaultsStorage.appPrivate.object(forKey: UserDefaultsStorage.Keys.isSpellingCorrectionsEnabled) as? Bool ?? true
        guard isEnabled else { return [] }

        guard let container = modelContainer else { return [] }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])

        guard let items = try? context.fetch(descriptor), !items.isEmpty else {
            return []
        }

        let words = items.map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        // De-duplicate while preserving order
        var seen = Set<String>()
        var unique: [String] = []
        for word in words {
            let key = word.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(word)
            }
            if let max = maxTerms, unique.count >= max {
                break
            }
        }
        return unique
    }
}
