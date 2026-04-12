//
//  SmartSearchConversation.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import Foundation
import SwiftData

/// A SwiftData model representing a RAG-powered Smart Search conversation.
///
/// Unlike ``MultiNoteConversation`` which uses a frozen snapshot of pre-selected notes,
/// Smart Search dynamically retrieves relevant note chunks per message via vector search.
/// There is typically one persistent conversation per user.
@Model
final class SmartSearchConversation {
    var id: UUID = UUID()
    var title: String = "Smart Search"
    var createdAt: Date = Date()

    /// Encoded Apple FM `Transcript` data for session restoration.
    var appleFMTranscriptData: Data?

    /// Chat messages in this conversation.
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]? = []

    init() {}
}
