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
/// this model is standalone. The assembled note text is captured at creation
/// time and stored directly, with no live references to source transcriptions.
@Model
final class MultiNoteConversation {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()

    /// Encoded Apple FM `Transcript` data for session restoration.
    var appleFMTranscriptData: Data?

    /// The assembled note context captured at creation time (XML NOTE tags).
    var noteContext: String = ""

    /// Number of source notes included at creation time.
    var sourceNoteCount: Int = 0

    /// Chat messages in this conversation.
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]? = []

    init() {}
}
