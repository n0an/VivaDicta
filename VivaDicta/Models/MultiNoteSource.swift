//
//  MultiNoteSource.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import SwiftData

/// Junction model linking a ``MultiNoteConversation`` to a ``Transcription``.
///
/// Follows the same CloudKit-safe pattern as ``TranscriptionTagAssignment``.
/// When the source transcription is deleted, this record's `transcription`
/// becomes nil but the conversation survives.
@Model
final class MultiNoteSource {
    var id: UUID = UUID()
    var addedAt: Date = Date()

    /// The conversation this source belongs to.
    @Relationship(inverse: \MultiNoteConversation.sources)
    var conversation: MultiNoteConversation?

    /// The source transcription. Becomes nil if the note is deleted.
    @Relationship
    var transcription: Transcription?

    init(transcription: Transcription? = nil) {
        self.transcription = transcription
    }
}
