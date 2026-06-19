// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import SwiftData
import Testing
@testable import VivaDicta

/// Integration tests for the `Transcription` + `TranscriptionVariation`
/// dual-write persistence contract, exercised against a REAL (in-memory)
/// SwiftData store.
///
/// This is the riskiest surface to refactor during modularization: the record
/// flow writes BOTH `transcription.enhancedText` and a linked
/// `TranscriptionVariation`, and the relationship cascades on delete. Each test
/// inserts through one `ModelContext` and re-reads through a FRESH one off the
/// same store, so it proves the data reached the store (not just the writing
/// context) - the Essential Developer "separate instances prove persistence"
/// shape. These pin the contract so it can't silently change when the models or
/// their storage move into a module.
@Suite(.tags(.database, .integration))
struct TranscriptionPersistenceIntegrationTests {

    let container: ModelContainer

    init() throws {
        container = try TestModelContainer.makeInMemory()
    }

    // MARK: - Dual write

    @Test func dualWrite_persistsEnhancedTextAndLinkedVariation() throws {
        let writeContext = ModelContext(container)
        let sut = Transcription(text: "raw transcript", enhancedText: "enhanced transcript", audioDuration: 12)
        let variation = TranscriptionVariation(
            presetId: "regular",
            presetDisplayName: "Regular",
            text: "enhanced transcript",
            aiModelName: "claude-sonnet-4-6",
            aiProviderName: "Anthropic"
        )
        variation.transcription = sut
        writeContext.insert(sut)
        writeContext.insert(variation)
        try writeContext.save()

        // Fresh context off the same store: proves it persisted, not just lived
        // in the writing context.
        let readContext = ModelContext(container)
        let fetched = try readContext.fetch(FetchDescriptor<Transcription>())

        #expect(fetched.count == 1)
        let stored = try #require(fetched.first)
        #expect(stored.text == "raw transcript")
        #expect(stored.enhancedText == "enhanced transcript")
        #expect(stored.variations?.count == 1)
        #expect(stored.variations?.first?.text == "enhanced transcript")
        #expect(stored.variations?.first?.aiProviderName == "Anthropic")
    }

    @Test func variation_inverseRelationship_pointsBackToTranscription() throws {
        let writeContext = ModelContext(container)
        let transcription = Transcription(text: "raw", audioDuration: 5)
        let variation = TranscriptionVariation(presetId: "summary", text: "summary text")
        variation.transcription = transcription
        writeContext.insert(transcription)
        writeContext.insert(variation)
        try writeContext.save()

        let readContext = ModelContext(container)
        let storedVariation = try #require(try readContext.fetch(FetchDescriptor<TranscriptionVariation>()).first)

        #expect(storedVariation.transcription?.text == "raw")
    }

    @Test func multipleVariations_allPersistAndLinkToOneTranscription() throws {
        let writeContext = ModelContext(container)
        let transcription = Transcription(text: "raw", audioDuration: 8)
        writeContext.insert(transcription)
        for (presetId, text) in [("regular", "regular text"), ("summary", "summary text"), ("email", "email text")] {
            let variation = TranscriptionVariation(presetId: presetId, text: text)
            variation.transcription = transcription
            writeContext.insert(variation)
        }
        try writeContext.save()

        let readContext = ModelContext(container)
        let stored = try #require(try readContext.fetch(FetchDescriptor<Transcription>()).first)

        #expect(stored.variations?.count == 3)
        #expect(Set(stored.variations?.map(\.presetId) ?? []) == ["regular", "summary", "email"])
    }

    // MARK: - Cascade delete

    @Test func deletingTranscription_cascadesToItsVariations() throws {
        let writeContext = ModelContext(container)
        let transcription = Transcription(text: "raw", enhancedText: "enhanced", audioDuration: 8)
        let variation = TranscriptionVariation(presetId: "regular", text: "enhanced")
        variation.transcription = transcription
        writeContext.insert(transcription)
        writeContext.insert(variation)
        try writeContext.save()

        writeContext.delete(transcription)
        try writeContext.save()

        let readContext = ModelContext(container)
        let remainingTranscriptions = try readContext.fetch(FetchDescriptor<Transcription>())
        let remainingVariations = try readContext.fetch(FetchDescriptor<TranscriptionVariation>())

        #expect(remainingTranscriptions.isEmpty)
        #expect(remainingVariations.isEmpty)   // .cascade removed the variation with its parent
    }

    // MARK: - Plain (un-enhanced) transcription

    @Test func transcriptionWithoutEnhancement_persistsWithNoVariations() throws {
        let writeContext = ModelContext(container)
        let sut = Transcription(text: "just a raw note", audioDuration: 3)
        writeContext.insert(sut)
        try writeContext.save()

        let readContext = ModelContext(container)
        let stored = try #require(try readContext.fetch(FetchDescriptor<Transcription>()).first)

        #expect(stored.text == "just a raw note")
        #expect(stored.enhancedText == nil)
        #expect(stored.variations?.isEmpty == true)
    }
}
