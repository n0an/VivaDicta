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

    /// When this conversation last changed, used for chats list ordering.
    var lastInteractionAt: Date = Date()

    /// Encoded Apple FM `Transcript` data for session restoration without replay.
    var appleFMTranscriptData: Data?

    /// Chat messages in this conversation.
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]? = []

    /// The transcription note this conversation is about.
    @Relationship
    var transcription: Transcription?

    init() {}
}
