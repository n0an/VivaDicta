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
    private let userDefaults = UserDefaultsStorage.appPrivate

    var words: [String] = []

    init() {
        loadWords()
    }

    private func loadWords() {
        words = userDefaults.stringArray(forKey: UserDefaultsStorage.Keys.customVocabularyWords) ?? []
        logger.logInfo("Loaded \(self.words.count) vocabulary words")
    }

    private func saveWords() {
        userDefaults.set(words, forKey: UserDefaultsStorage.Keys.customVocabularyWords)
    }

    func addWord(_ word: String) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

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

    func deleteWords(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        saveWords()
        logger.logInfo("Deleted \(offsets.count) vocabulary words")
    }

    /// Returns a comma-separated string of all vocabulary words for use in AI prompts
    func getCustomVocabulary() -> String {
        let vocabularyString = words.joined(separator: ", ")
        if !vocabularyString.isEmpty {
            logger.logInfo("Generated vocabulary string with \(self.words.count) words")
        }
        return vocabularyString
    }
}
