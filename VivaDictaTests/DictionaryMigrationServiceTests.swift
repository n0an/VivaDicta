//
//  DictionaryMigrationServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.27
//

import Foundation
import AppGroup
import SwiftData
import Testing
@testable import VivaDicta

@MainActor
@Suite(.tags(.database))
struct DictionaryMigrationServiceTests {

    private let migrationCompletedKey = "HasMigratedDictionaryToSwiftData"

    private func makeDefaults() -> (source: UserDefaults, flag: UserDefaults) {
        let sourceName = "DictionaryMigrationTests.source.\(UUID().uuidString)"
        let flagName = "DictionaryMigrationTests.flag.\(UUID().uuidString)"
        let source = UserDefaults(suiteName: sourceName)!
        source.removePersistentDomain(forName: sourceName)
        let flag = UserDefaults(suiteName: flagName)!
        flag.removePersistentDomain(forName: flagName)
        return (source, flag)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: VocabularyWord.self, WordReplacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    private func fetchVocabulary(in context: ModelContext) throws -> [VocabularyWord] {
        try context.fetch(FetchDescriptor<VocabularyWord>())
    }

    private func fetchReplacements(in context: ModelContext) throws -> [WordReplacement] {
        try context.fetch(FetchDescriptor<WordReplacement>())
    }

    // MARK: - Flag short-circuit

    @Test func migrateIfNeeded_isNoOp_whenAlreadyMigrated() throws {
        let (source, flag) = makeDefaults()
        source.set(["hello", "world"], forKey: UserDefaultsStorage.Keys.customVocabularyWords)
        flag.set(true, forKey: migrationCompletedKey)
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)

        #expect(try fetchVocabulary(in: context).isEmpty)
    }

    // MARK: - Vocabulary migration

    @Test func migrateIfNeeded_migratesVocabularyWords_intoSwiftData() throws {
        let (source, flag) = makeDefaults()
        source.set(["swift", "swiftdata", "xcode"], forKey: UserDefaultsStorage.Keys.customVocabularyWords)
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)

        let migrated = try fetchVocabulary(in: context).map(\.word).sorted()
        #expect(migrated == ["swift", "swiftdata", "xcode"])
    }

    @Test func migrateIfNeeded_skipsEmptyAndWhitespaceVocabularyEntries() throws {
        let (source, flag) = makeDefaults()
        source.set(["valid", "   ", "", "  trimmed  "], forKey: UserDefaultsStorage.Keys.customVocabularyWords)
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)

        let migrated = try fetchVocabulary(in: context).map(\.word).sorted()
        #expect(migrated == ["trimmed", "valid"])
    }

    // MARK: - Replacements migration

    @Test func migrateIfNeeded_migratesWordReplacements_intoSwiftData() throws {
        let (source, flag) = makeDefaults()
        let legacy = [
            LegacyReplacementWire(id: UUID(), original: "u", replacement: "you"),
            LegacyReplacementWire(id: UUID(), original: "btw", replacement: "by the way")
        ]
        source.set(try JSONEncoder().encode(legacy), forKey: UserDefaultsStorage.Keys.textReplacements)
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)

        let migrated = try fetchReplacements(in: context)
            .map { ($0.originalText, $0.replacementText) }
            .sorted { $0.0 < $1.0 }
        #expect(migrated.count == 2)
        #expect(migrated[0] == ("btw", "by the way"))
        #expect(migrated[1] == ("u", "you"))
    }

    // MARK: - Flag set after run

    @Test func migrateIfNeeded_setsCompletionFlag_afterRun() throws {
        let (source, flag) = makeDefaults()
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)

        #expect(flag.bool(forKey: migrationCompletedKey))
    }

    @Test func migrateIfNeeded_setsCompletionFlag_evenWithNothingToMigrate() throws {
        let (source, flag) = makeDefaults()
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)

        #expect(flag.bool(forKey: migrationCompletedKey))
        #expect(try fetchVocabulary(in: context).isEmpty)
        #expect(try fetchReplacements(in: context).isEmpty)
    }

    // MARK: - Idempotency

    @Test func migrateIfNeeded_secondCall_doesNotDuplicateRecords() throws {
        let (source, flag) = makeDefaults()
        source.set(["hello"], forKey: UserDefaultsStorage.Keys.customVocabularyWords)
        let context = try makeContext()

        let sut = DictionaryMigrationService(sourceDefaults: source, flagDefaults: flag)
        sut.migrateIfNeeded(context: context)
        sut.migrateIfNeeded(context: context)

        #expect(try fetchVocabulary(in: context).count == 1)
    }
}

/// Local mirror of the private `LegacyReplacement` payload that the SUT decodes.
/// Kept in tests so the wire format is documented next to the assertions.
private struct LegacyReplacementWire: Codable {
    let id: UUID
    let original: String
    let replacement: String
}
