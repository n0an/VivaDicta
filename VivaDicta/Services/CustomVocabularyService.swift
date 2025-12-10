//
//  CustomVocabularyService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import Foundation
import SwiftUI
import os

@Observable
class CustomVocabularyService {
    private let logger = Logger(category: .customVocabulary)
    private let userDefaults: UserDefaults
    private let storageKey: String

    /// Maximum character length for a single word
    static let maxWordLength = 50

    var words: [String] = []

    init(userDefaults: UserDefaults = UserDefaultsStorage.appPrivate,
         storageKey: String = UserDefaultsStorage.Keys.customVocabularyWords) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        loadWords()
    }

    private func loadWords() {
        words = userDefaults.stringArray(forKey: storageKey) ?? []
        logger.logInfo("Loaded \(self.words.count) vocabulary words")
    }

    private func saveWords() {
        userDefaults.set(words, forKey: storageKey)
    }

    func addWord(_ word: String) {
        var trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        // Truncate word if too long
        if trimmedWord.count > Self.maxWordLength {
            trimmedWord = String(trimmedWord.prefix(Self.maxWordLength))
            logger.logInfo("Truncated word to \(Self.maxWordLength) characters")
        }

        // Check for duplicates (case-insensitive)
        let isDuplicate = words.contains { $0.lowercased() == trimmedWord.lowercased() }
        guard !isDuplicate else {
            logger.logWarning("Word already exists: \(trimmedWord)")
            return
        }

        words.insert(trimmedWord, at: 0)
        saveWords()
        logger.logInfo("Added vocabulary word: \(trimmedWord)")
    }

    func deleteWord(_ word: String) {
        words.removeAll { $0 == word }
        saveWords()
        logger.logInfo("Deleted vocabulary word: \(word)")
    }

    func updateWord(_ oldWord: String, to newWord: String) {
        var trimmedWord = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        // Truncate word if too long
        if trimmedWord.count > Self.maxWordLength {
            trimmedWord = String(trimmedWord.prefix(Self.maxWordLength))
            logger.logInfo("Truncated word to \(Self.maxWordLength) characters")
        }

        // Check for duplicates (case-insensitive), excluding the word being edited
        let isDuplicate = words.contains { $0.lowercased() == trimmedWord.lowercased() && $0 != oldWord }
        guard !isDuplicate else {
            logger.logWarning("Word already exists: \(trimmedWord)")
            return
        }

        if let index = words.firstIndex(of: oldWord) {
            words[index] = trimmedWord
            saveWords()
            logger.logInfo("Updated vocabulary word: \(oldWord) -> \(trimmedWord)")
        }
    }

    func deleteWords(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        saveWords()
        logger.logInfo("Deleted \(offsets.count) vocabulary words")
    }
}
