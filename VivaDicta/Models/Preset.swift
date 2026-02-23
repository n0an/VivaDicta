//
//  Preset.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import SwiftUI

/// A unified AI text processing preset that replaces both `UserPrompt` and `RewritePreset`.
///
/// Presets define how AI processes transcription text. There are two behavioral modes:
///
/// - **Enhancement presets** (`useSystemTemplate = true`): `promptInstructions` are injected
///   into the TRANSCRIPTION ENHANCER system prompt wrapper. Used for cleaning up transcriptions.
///
/// - **Standalone presets** (`useSystemTemplate = false`): `promptInstructions` IS the full
///   system message. Used for summarizing, translating, rewriting tone, etc.
///
/// Built-in presets are editable but not deletable. Custom presets are synced
/// via ``RewritePreset`` SwiftData records through CloudKit.
struct Preset: Identifiable, Codable, Equatable, Hashable {
    /// Stable string identifier. Built-in presets use readable IDs (e.g., "regular", "email").
    /// Custom presets use "custom_<UUID>" format.
    let id: String

    /// User-visible name of the preset.
    var name: String

    /// Icon for display. Can be an emoji or SF Symbol name.
    var icon: String

    /// Grouping category: "Rewrite", "Summarize", "Translate", "Other".
    var category: String

    /// The prompt text. For enhancement presets, this gets wrapped in the system template.
    /// For standalone presets, this IS the full system message.
    var promptInstructions: String

    /// When `true`, `promptInstructions` are injected into the TRANSCRIPTION ENHANCER
    /// system prompt wrapper via `PromptsTemplates.systemPrompt(with:)`.
    /// When `false`, `promptInstructions` are used directly as the system message.
    var useSystemTemplate: Bool

    /// When `true`, the input text is wrapped in `<TRANSCRIPT>` tags before sending to AI.
    var wrapInTranscriptTags: Bool

    /// Built-in presets cannot be deleted (only edited and reset).
    let isBuiltIn: Bool

    /// Whether a built-in preset has been modified by the user.
    var isEdited: Bool

    /// When this preset was created.
    let createdAt: Date

    /// Whether the icon string is an emoji (as opposed to an SF Symbol name).
    var iconIsEmoji: Bool {
        guard let first = icon.unicodeScalars.first else { return false }
        return first.properties.isEmoji && first.value > 0x238C
    }

    init(id: String,
         name: String,
         icon: String,
         category: String,
         promptInstructions: String,
         useSystemTemplate: Bool,
         wrapInTranscriptTags: Bool = true,
         isBuiltIn: Bool = false,
         isEdited: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.promptInstructions = promptInstructions
        self.useSystemTemplate = useSystemTemplate
        self.wrapInTranscriptTags = wrapInTranscriptTags
        self.isBuiltIn = isBuiltIn
        self.isEdited = isEdited
        self.createdAt = createdAt
    }
}

/// Renders a preset icon as either an emoji `Text` or an SF Symbol `Image`.
struct PresetIconView: View {
    let icon: String
    var fontSize: CGFloat = 14

    private var isEmoji: Bool {
        guard let first = icon.unicodeScalars.first else { return false }
        return first.properties.isEmoji && first.value > 0x238C
    }

    var body: some View {
        if isEmoji {
            Text(icon)
                .font(.system(size: fontSize))
        } else {
            Image(systemName: icon)
                .font(.system(size: fontSize))
        }
    }
}
