//
//  ChatConversation.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation
import SwiftData

/// A SwiftData model representing a chat conversation about one or more transcription notes.
///
/// Decouples chat from a single ``Transcription``, enabling both single-note and
/// multi-note conversations (e.g., "chat with all notes tagged Work").
@Model
final class ChatConversation {
    var id: UUID = UUID()

    /// When this conversation was created.
    var createdAt: Date = Date()

    /// Persisted AI provider name for this conversation.
    var aiProviderName: String?

    /// Persisted AI model name for this conversation.
    var aiModelName: String?

    /// Encoded Apple FM `Transcript` data for session restoration without replay.
    var appleFMTranscriptData: Data?

    /// Chat messages in this conversation.
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]? = []

    /// Source transcription notes this conversation is about.
    @Relationship
    var sourceTranscriptions: [Transcription]? = []

    init() {}
}
