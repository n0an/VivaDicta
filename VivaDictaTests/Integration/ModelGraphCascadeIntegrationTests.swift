// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import SwiftData
import Testing
@testable import VivaDicta

/// Integration tests for the model graph's **delete-rule contract** against a
/// real in-memory store.
///
/// These cascade/nullify rules are exactly what breaks silently when models move
/// into a module or the CloudKit schema changes - and they're invisible to unit
/// tests. Each test inserts the graph through one `ModelContext`, deletes through
/// it, and re-reads through a fresh one, so it pins the persisted behavior end to
/// end (the Essential Developer "integration: real store, separate instances"
/// shape).
@Suite(.tags(.database, .integration))
struct ModelGraphCascadeIntegrationTests {

    let container: ModelContainer

    init() throws {
        container = try TestModelContainer.makeInMemory()
    }

    /// Deleting a `Transcription` must cascade its entire *owned* graph
    /// (variations, tag assignments, chat conversations + their messages) but
    /// only *nullify* the many-to-many multi-note link, which survives.
    @Test func deletingTranscription_cascadesOwnedGraph_butNullifiesMultiNoteLink() throws {
        let writeContext = ModelContext(container)
        let transcription = Transcription(text: "note", enhancedText: "enhanced", audioDuration: 5)

        let variation = TranscriptionVariation(presetId: "regular", text: "enhanced")
        variation.transcription = transcription

        let conversation = ChatConversation()
        conversation.transcription = transcription
        let message = ChatMessage(role: "user", content: "hello")
        conversation.messages = [message]

        let assignment = TranscriptionTagAssignment(tagId: UUID(), transcription: transcription)

        let reminder = ExtractedReminderDraft(title: "buy milk")
        reminder.transcription = transcription

        let multiNote = MultiNoteConversation()
        multiNote.transcriptions = [transcription]

        writeContext.insert(transcription)
        writeContext.insert(variation)
        writeContext.insert(conversation)
        writeContext.insert(message)
        writeContext.insert(assignment)
        writeContext.insert(reminder)
        writeContext.insert(multiNote)
        try writeContext.save()

        // Pre-delete control: prove the owned graph was actually linked + persisted,
        // so the post-delete `isEmpty` checks can't pass for the wrong reason.
        #expect(try writeContext.fetch(FetchDescriptor<TranscriptionVariation>()).count == 1)
        #expect(try writeContext.fetch(FetchDescriptor<ChatConversation>()).count == 1)
        #expect(try writeContext.fetch(FetchDescriptor<ChatMessage>()).count == 1)
        #expect(try writeContext.fetch(FetchDescriptor<TranscriptionTagAssignment>()).count == 1)
        #expect(try writeContext.fetch(FetchDescriptor<ExtractedReminderDraft>()).count == 1)

        writeContext.delete(transcription)
        try writeContext.save()

        let read = ModelContext(container)
        #expect(try read.fetch(FetchDescriptor<Transcription>()).isEmpty)
        #expect(try read.fetch(FetchDescriptor<TranscriptionVariation>()).isEmpty)       // .cascade
        #expect(try read.fetch(FetchDescriptor<ChatConversation>()).isEmpty)             // .cascade
        #expect(try read.fetch(FetchDescriptor<ChatMessage>()).isEmpty)                  // two-level cascade
        #expect(try read.fetch(FetchDescriptor<TranscriptionTagAssignment>()).isEmpty)   // .cascade
        #expect(try read.fetch(FetchDescriptor<ExtractedReminderDraft>()).isEmpty)       // .cascade

        // .nullify: the multi-note conversation survives, just loses the link.
        let survivor = try #require(try read.fetch(FetchDescriptor<MultiNoteConversation>()).first)
        #expect(survivor.transcriptions?.isEmpty == true)
    }

    /// Deleting a single chat conversation cascades its messages but leaves the
    /// note it was about untouched.
    @Test func deletingChatConversation_cascadesMessages_leavesTranscription() throws {
        let writeContext = ModelContext(container)
        let transcription = Transcription(text: "note", audioDuration: 5)
        let conversation = ChatConversation()
        conversation.transcription = transcription
        conversation.messages = [ChatMessage(content: "one"), ChatMessage(content: "two")]
        writeContext.insert(transcription)
        writeContext.insert(conversation)
        try writeContext.save()

        #expect(try writeContext.fetch(FetchDescriptor<ChatMessage>()).count == 2)   // linked & persisted

        writeContext.delete(conversation)
        try writeContext.save()

        let read = ModelContext(container)
        #expect(try read.fetch(FetchDescriptor<ChatConversation>()).isEmpty)
        #expect(try read.fetch(FetchDescriptor<ChatMessage>()).isEmpty)        // .cascade
        #expect(try read.fetch(FetchDescriptor<Transcription>()).count == 1)   // the note is untouched
    }

    /// A multi-note conversation owns its messages (cascade) but only *references*
    /// its transcriptions (many-to-many) - deleting it must not delete the notes.
    @Test func deletingMultiNoteConversation_cascadesMessages_butTranscriptionsSurvive() throws {
        let writeContext = ModelContext(container)
        let t1 = Transcription(text: "a", audioDuration: 1)
        let t2 = Transcription(text: "b", audioDuration: 1)
        let multiNote = MultiNoteConversation()
        multiNote.transcriptions = [t1, t2]
        multiNote.messages = [ChatMessage(content: "question")]
        writeContext.insert(t1)
        writeContext.insert(t2)
        writeContext.insert(multiNote)
        try writeContext.save()

        #expect(try writeContext.fetch(FetchDescriptor<ChatMessage>()).count == 1)   // linked & persisted

        writeContext.delete(multiNote)
        try writeContext.save()

        let read = ModelContext(container)
        #expect(try read.fetch(FetchDescriptor<MultiNoteConversation>()).isEmpty)
        #expect(try read.fetch(FetchDescriptor<ChatMessage>()).isEmpty)         // .cascade
        // `transcriptions` has no explicit deleteRule, so this pins the IMPLICIT
        // default (.nullify): a future "tidy-up" adding an explicit rule must keep it.
        #expect(try read.fetch(FetchDescriptor<Transcription>()).count == 2)    // many-to-many: notes survive
    }
}
