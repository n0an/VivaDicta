//
//  TranscriptionVariation.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import SwiftData

/// A SwiftData model representing an AI-generated text variation of a transcription.
///
/// Each variation is produced by applying a specific preset (e.g., Summary, Action Points,
/// Professional Tone) to the original transcription text. Multiple variations can be
/// associated with a single ``Transcription`` via a one-to-many relationship.
///
/// The "enhanced" preset is special — it corresponds to the standard AI enhancement
/// and is created automatically during transcription or migrated from legacy `enhancedText`.
@Model
final class TranscriptionVariation {
    var id: UUID = UUID()

    /// Identifier of the preset used to generate this variation (e.g., "enhanced", "summary", "action_points").
    var presetId: String = ""

    /// Display name of the preset at the time of generation, stored for historical context.
    var presetDisplayName: String = ""

    /// The AI-generated text for this variation.
    var text: String = ""

    /// When this variation was created.
    var createdAt: Date = Date()

    /// Name of the AI model used to generate this variation.
    var aiModelName: String?

    /// Name of the AI provider used to generate this variation.
    var aiProviderName: String?

    /// Duration of the AI processing in seconds.
    var processingDuration: TimeInterval?

    /// The parent transcription this variation belongs to.
    @Relationship(inverse: \Transcription.variations)
    var transcription: Transcription?

    init(presetId: String = "",
         presetDisplayName: String = "",
         text: String = "",
         createdAt: Date = Date(),
         aiModelName: String? = nil,
         aiProviderName: String? = nil,
         processingDuration: TimeInterval? = nil) {
        self.presetId = presetId
        self.presetDisplayName = presetDisplayName
        self.text = text
        self.createdAt = createdAt
        self.aiModelName = aiModelName
        self.aiProviderName = aiProviderName
        self.processingDuration = processingDuration
    }
}
