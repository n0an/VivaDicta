//
//  CustomVocabulary.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.08
//

import Foundation

enum CustomVocabulary {
    /// Retrieves custom vocabulary terms from user defaults, trimmed, deduplicated, and optionally limited.
    /// - Parameter maxTerms: Optional maximum number of terms to return. If nil, returns all terms.
    /// - Returns: Array of unique vocabulary terms, preserving original order.
    static func getTerms(maxTerms: Int? = nil) -> [String] {
        guard let words = UserDefaultsStorage.appPrivate.stringArray(forKey: UserDefaultsStorage.Keys.customVocabularyWords) else {
            return []
        }

        let trimmedWords = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // De-duplicate while preserving order
        var seen = Set<String>()
        var unique: [String] = []
        for word in trimmedWords {
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
