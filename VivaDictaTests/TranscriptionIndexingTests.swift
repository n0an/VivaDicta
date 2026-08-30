// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import VivaDicta

/// `Dictionary(uniqueKeysWithValues:)` traps on a repeated key, and every notes
/// screen that looks a note up by id was building one that way. Two rows can
/// share an `id` - CloudKit-synced models cannot carry `@Attribute(.unique)`,
/// so nothing at the storage layer prevents it - and the list crashed on the
/// next search instead of showing the duplicate.
struct TranscriptionIndexingTests {

    private func makeTranscription(text: String, id: UUID? = nil) -> Transcription {
        let transcription = Transcription(text: text, audioDuration: 1)
        if let id { transcription.id = id }
        return transcription
    }

    @Test func indexesEachNoteByItsID() {
        let first = makeTranscription(text: "first")
        let second = makeTranscription(text: "second")

        let index = [first, second].indexedByID

        #expect(index.count == 2)
        #expect(index[first.id]?.text == "first")
        #expect(index[second.id]?.text == "second")
    }

    // The crash this exists to prevent.
    @Test func duplicateIDsDoNotTrap() {
        let sharedID = UUID()
        let first = makeTranscription(text: "first", id: sharedID)
        let duplicate = makeTranscription(text: "duplicate", id: sharedID)

        let index = [first, duplicate].indexedByID

        #expect(index.count == 1)
        #expect(index[sharedID]?.text == "first", "first one wins")
    }

    @Test func laterDuplicatesDoNotDisplaceEarlierNotes() {
        let sharedID = UUID()
        let unique = makeTranscription(text: "unique")
        let first = makeTranscription(text: "first", id: sharedID)
        let second = makeTranscription(text: "second", id: sharedID)
        let third = makeTranscription(text: "third", id: sharedID)

        let index = [unique, first, second, third].indexedByID

        #expect(index.count == 2)
        #expect(index[sharedID]?.text == "first")
        #expect(index[unique.id]?.text == "unique")
    }

    @Test func emptyCollectionIndexesToAnEmptyDictionary() {
        #expect([Transcription]().indexedByID.isEmpty)
    }
}
