//
//  ChatMessage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation
import SwiftData

/// A SwiftData model representing a single message in a "Chat with Note" conversation.
///
/// Each chat message belongs to a ``Transcription`` via a one-to-many relationship.
/// Messages can be user-authored, AI-generated responses, or compaction summaries
/// that replace older messages to manage context window limits.
@Model
final class ChatMessage {
    var id: UUID = UUID()

    /// The role of this message: "user", "assistant", or "summary".
    var role: String = "user"

    /// The text content of this message.
    var content: String = ""

    /// When this message was created.
    var createdAt: Date = Date()

    /// Name of the AI provider that generated this response (nil for user messages).
    var aiProviderName: String?

    /// Name of the AI model that generated this response (nil for user messages).
    var aiModelName: String?

    /// Whether this message represents a failed AI response.
    var isError: Bool = false

    /// Whether this message is a compaction summary replacing older messages.
    var isSummary: Bool = false

    /// Pre-computed token estimate for context window management.
    var estimatedTokenCount: Int = 0

    /// The parent transcription this chat message belongs to.
    @Relationship(inverse: \Transcription.chatMessages)
    var transcription: Transcription?

    init(role: String = "user",
         content: String = "",
         aiProviderName: String? = nil,
         aiModelName: String? = nil,
         isError: Bool = false,
         isSummary: Bool = false,
         estimatedTokenCount: Int = 0) {
        self.role = role
        self.content = content
        self.aiProviderName = aiProviderName
        self.aiModelName = aiModelName
        self.isError = isError
        self.isSummary = isSummary
        self.estimatedTokenCount = estimatedTokenCount
    }
}
