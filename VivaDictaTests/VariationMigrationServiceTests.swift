//
//  VariationMigrationServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import SwiftData
import Testing
@testable import VivaDicta

@MainActor
struct VariationMigrationServiceTests {

    private let migrationKey = "HasMigratedEnhancedTextToVariations_v1"

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Transcription.self, configurations: config)
    }

    private func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }

    // MARK: - Migration Tests

    @Test func migrateIfNeeded_migratesEnhancedTextToVariation() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        let transcription = Transcription(
            text: "Original text",
            enhancedText: "AI processed text",
            audioDuration: 10.0
        )
        transcription.aiEnhancementModelName = "gpt-4"
        transcription.aiProviderName = "OpenAI"
        transcription.enhancementDuration = 1.5
        transcription.promptName = "Custom Prompt"
        context.insert(transcription)
        try context.save()

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        let variations = try context.fetch(FetchDescriptor<TranscriptionVariation>())
        #expect(variations.count == 1)
        #expect(variations.first?.text == "AI processed text")
        #expect(variations.first?.presetId == "regular")
        #expect(variations.first?.aiModelName == "gpt-4")
        #expect(variations.first?.aiProviderName == "OpenAI")
        #expect(variations.first?.processingDuration == 1.5)
        #expect(variations.first?.transcription === transcription)

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_skipsEmptyEnhancedText() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        let transcription1 = Transcription(text: "No AI output", audioDuration: 10.0)
        let transcription2 = Transcription(text: "Empty AI output", enhancedText: "", audioDuration: 5.0)
        context.insert(transcription1)
        context.insert(transcription2)
        try context.save()

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        let variations = try context.fetch(FetchDescriptor<TranscriptionVariation>())
        #expect(variations.isEmpty)

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_setsCompletionFlag() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        #expect(UserDefaults.standard.bool(forKey: migrationKey) == false)

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        #expect(UserDefaults.standard.bool(forKey: migrationKey) == true)

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_doesNotRunTwice() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        let transcription = Transcription(
            text: "Original",
            enhancedText: "Processed",
            audioDuration: 10.0
        )
        context.insert(transcription)
        try context.save()

        // First migration
        VariationMigrationService.shared.migrateIfNeeded(context: context)
        let countAfterFirst = try context.fetch(FetchDescriptor<TranscriptionVariation>()).count

        // Second migration should be a no-op
        VariationMigrationService.shared.migrateIfNeeded(context: context)
        let countAfterSecond = try context.fetch(FetchDescriptor<TranscriptionVariation>()).count

        #expect(countAfterFirst == 1)
        #expect(countAfterSecond == 1)

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_migratesMultipleTranscriptions() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        for i in 1...5 {
            let t = Transcription(
                text: "Original \(i)",
                enhancedText: "Processed \(i)",
                audioDuration: Double(i) * 10.0
            )
            context.insert(t)
        }
        try context.save()

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        let variations = try context.fetch(FetchDescriptor<TranscriptionVariation>())
        #expect(variations.count == 5)

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_preservesTimestampFromTranscription() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        let transcription = Transcription(
            text: "Original",
            enhancedText: "Processed",
            audioDuration: 10.0
        )
        context.insert(transcription)
        try context.save()

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        let variations = try context.fetch(FetchDescriptor<TranscriptionVariation>())
        #expect(variations.first?.createdAt == transcription.timestamp)

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_setsPresetDisplayName() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        let transcription = Transcription(
            text: "Original",
            enhancedText: "Processed",
            audioDuration: 10.0
        )
        transcription.promptName = "Summary"
        context.insert(transcription)
        try context.save()

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        let variations = try context.fetch(FetchDescriptor<TranscriptionVariation>())
        #expect(variations.first?.presetDisplayName == "Summary")

        resetMigrationFlag()
    }

    @Test func migrateIfNeeded_usesDefaultDisplayNameWhenPromptNameNil() throws {
        resetMigrationFlag()
        let container = try makeContainer()
        let context = container.mainContext

        let transcription = Transcription(
            text: "Original",
            enhancedText: "Processed",
            audioDuration: 10.0
        )
        transcription.promptName = nil
        context.insert(transcription)
        try context.save()

        VariationMigrationService.shared.migrateIfNeeded(context: context)

        let variations = try context.fetch(FetchDescriptor<TranscriptionVariation>())
        #expect(variations.first?.presetDisplayName == "Regular")

        resetMigrationFlag()
    }
}
