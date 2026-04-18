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
/// this model keeps both a live relationship to its source transcriptions
/// (for navigation) and a frozen ``noteContext`` snapshot (for AI context integrity).
@Model
final class MultiNoteConversation {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var lastInteractionAt: Date = Date()

    /// Encoded Apple FM `Transcript` data for session restoration.
    var appleFMTranscriptData: Data?

    /// The assembled note context captured at creation time (XML NOTE tags).
    var noteContext: String = ""

    /// Number of source notes included at creation time.
    var sourceNoteCount: Int = 0

    /// True when this conversation was created from the "All Notes" shortcut,
    /// which auto-picks the most recent notes that fit the provider's budget.
    /// False for regular multi-note chats where the user hand-picked notes.
    var isAllNotes: Bool = false

    /// Chat messages in this conversation.
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]? = []

    /// Source transcriptions this conversation is about.
    /// Kept for navigation/UI; the AI uses the frozen ``noteContext`` snapshot.
    @Relationship
    var transcriptions: [Transcription]? = []

    init() {}
}
