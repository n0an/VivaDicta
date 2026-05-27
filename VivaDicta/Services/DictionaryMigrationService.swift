import Foundation
import AppGroup
import SwiftData
import os

class DictionaryMigrationService {
    static let shared = DictionaryMigrationService(
        sourceDefaults: UserDefaultsStorage.appPrivate,
        flagDefaults: UserDefaults.standard
    )

    private let logger = Logger(category: .dictionaryMigration)
    private let sourceDefaults: UserDefaults
    private let flagDefaults: UserDefaults

    private let migrationCompletedKey = "HasMigratedDictionaryToSwiftData"

    init(
        sourceDefaults: UserDefaults = UserDefaultsStorage.appPrivate,
        flagDefaults: UserDefaults = UserDefaults.standard
    ) {
        self.sourceDefaults = sourceDefaults
        self.flagDefaults = flagDefaults
    }

    /// Migrates dictionary data from UserDefaults to SwiftData.
    /// This is a one-time operation that preserves all existing user data.
    func migrateIfNeeded(context: ModelContext) {
        if flagDefaults.bool(forKey: migrationCompletedKey) {
            return
        }

        logger.logInfo("Starting dictionary migration from UserDefaults to SwiftData")

        var vocabularyMigrated = 0
        var replacementsMigrated = 0

        // Migrate vocabulary words
        if let words = sourceDefaults.stringArray(forKey: UserDefaultsStorage.Keys.customVocabularyWords) {
            logger.logInfo("Found \(words.count) vocabulary words to migrate")

            for word in words {
                let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let vocabWord = VocabularyWord(word: trimmed)
                context.insert(vocabWord)
                vocabularyMigrated += 1
            }

            logger.logInfo("Migrated \(vocabularyMigrated) vocabulary words")
        }

        // Migrate word replacements
        if let data = sourceDefaults.data(forKey: UserDefaultsStorage.Keys.textReplacements),
           let oldReplacements = try? JSONDecoder().decode([LegacyReplacement].self, from: data) {
            logger.logInfo("Found \(oldReplacements.count) word replacements to migrate")

            for old in oldReplacements {
                let wordReplacement = WordReplacement(
                    originalText: old.original,
                    replacementText: old.replacement
                )
                context.insert(wordReplacement)
                replacementsMigrated += 1
            }

            logger.logInfo("Migrated \(replacementsMigrated) word replacements")
        }

        // Save the migrated data
        do {
            try context.save()
            flagDefaults.set(true, forKey: migrationCompletedKey)
            logger.logInfo("Dictionary migration completed successfully")
        } catch {
            logger.logError("Failed to save migrated dictionary data: \(error.localizedDescription)")
        }
    }
}

/// Legacy struct for decoding existing UserDefaults replacement data
private struct LegacyReplacement: Codable {
    let id: UUID
    let original: String
    let replacement: String
}
