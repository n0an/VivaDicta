//
//  ChatMessage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation
import SwiftData

struct SmartSearchSourceCitation: Codable, Hashable, Sendable {
    var transcriptionId: UUID
    var excerpt: String
    var relevanceScore: Float
}

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

    /// The single-note conversation this message belongs to (nil for multi-note messages).
    @Relationship(inverse: \ChatConversation.messages)
    var conversation: ChatConversation?

    /// The multi-note conversation this message belongs to (nil for single-note messages).
    @Relationship(inverse: \MultiNoteConversation.messages)
    var multiNoteConversation: MultiNoteConversation?

    /// The smart search conversation this message belongs to (nil for other chat types).
    @Relationship(inverse: \SmartSearchConversation.messages)
    var smartSearchConversation: SmartSearchConversation?

    /// JSON-encoded array of transcription UUID strings that were used as RAG sources
    /// for this assistant message. Nil for user messages and non-RAG responses.
    var sourceTranscriptionIdsData: Data?

    /// JSON-encoded Smart Search citation metadata for this assistant message.
    /// Stores the matched excerpt and score so the UI can show evidence, not only note titles.
    var sourceCitationsData: Data?

    /// Convenience accessor for source transcription IDs.
    var sourceTranscriptionIds: [UUID] {
        get {
            guard let data = sourceTranscriptionIdsData,
                  let strings = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return strings.compactMap { UUID(uuidString: $0) }
        }
        set {
            let strings = newValue.map(\.uuidString)
            sourceTranscriptionIdsData = try? JSONEncoder().encode(strings)
        }
    }

    var sourceCitations: [SmartSearchSourceCitation] {
        get {
            guard let data = sourceCitationsData,
                  let citations = try? JSONDecoder().decode([SmartSearchSourceCitation].self, from: data) else {
                return []
            }
            return citations
        }
        set {
            sourceCitationsData = try? JSONEncoder().encode(newValue)
        }
    }

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
