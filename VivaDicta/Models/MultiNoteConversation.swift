//
//  MultiNoteConversation.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import SwiftData

/// A SwiftData model representing a chat conversation about multiple transcription notes.
///
/// Unlike ``ChatConversation`` (1:1 with a single note, cascade-deleted),
/// this model survives individual source note deletion (nullify semantics).
/// Source notes are linked via ``MultiNoteSource`` junction records.
@Model
final class MultiNoteConversation {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()

    /// Encoded Apple FM `Transcript` data for session restoration.
    var appleFMTranscriptData: Data?

    /// How notes were selected: "all", "tags", or "manual".
    var selectionMode: String = "manual"

    /// JSON-encoded tag IDs when selectionMode is "tags".
    var tagFilterData: Data?

    /// Chat messages in this conversation.
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]? = []

    /// Junction records linking source transcriptions.
    @Relationship(deleteRule: .cascade)
    var sources: [MultiNoteSource]? = []

    init() {}
}
