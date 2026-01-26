//
//  VivaMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

/// A configuration preset combining transcription and AI enhancement settings.
///
/// `VivaMode` encapsulates all settings needed for a complete transcription workflow,
/// including which transcription model to use, which AI provider to enhance with,
/// and the prompt to guide enhancement.
///
/// ## Overview
///
/// Modes allow users to quickly switch between different configurations:
/// - A "Quick Notes" mode might use a fast local model with minimal enhancement
/// - A "Professional" mode might use a high-quality cloud model with detailed formatting
///
/// ## Properties
///
/// ### Transcription Settings
/// - ``transcriptionProvider``: Which provider (WhisperKit, Parakeet, or cloud)
/// - ``transcriptionModel``: The specific model name
/// - ``transcriptionLanguage``: Source audio language (or "auto" for detection)
///
/// ### Enhancement Settings
/// - ``aiEnhanceEnabled``: Whether to apply AI enhancement
/// - ``aiProvider``: Which AI provider to use (OpenAI, Anthropic, etc.)
/// - ``aiModel``: The specific AI model name
/// - ``userPrompt``: The prompt template guiding enhancement
///
/// ## Persistence
///
/// Modes are stored in UserDefaults via `AppGroupCoordinator` and shared with
/// the keyboard extension for Flow Mode functionality.
struct VivaMode: Identifiable, Hashable, Codable {
    /// Unique identifier for this mode.
    let id: UUID

    /// User-visible name for the mode.
    let name: String

    /// The transcription provider to use (WhisperKit, Parakeet, or cloud service).
    let transcriptionProvider: TranscriptionModelProvider

    /// The specific transcription model name within the provider.
    let transcriptionModel: String

    /// The language for transcription, or "auto" for automatic detection.
    let transcriptionLanguage: String?

    /// The prompt template for AI enhancement, if any.
    let userPrompt: UserPrompt?

    /// The AI provider for text enhancement.
    var aiProvider: AIProvider?

    /// The specific AI model name for enhancement.
    var aiModel: String

    /// Whether AI enhancement is enabled for this mode.
    let aiEnhanceEnabled: Bool

    /// Creates a new VivaMode with the specified settings.
    init(id: UUID,
         name: String,
         transcriptionProvider: TranscriptionModelProvider,
         transcriptionModel: String,
         transcriptionLanguage: String? = nil,
         userPrompt: UserPrompt? = nil,
         aiProvider: AIProvider? = nil,
         aiModel: String,
         aiEnhanceEnabled: Bool) {
        self.id = id
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguage = transcriptionLanguage
        self.userPrompt = userPrompt
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiEnhanceEnabled = aiEnhanceEnabled
    }
    
    /// The default mode used when no custom mode is configured.
    ///
    /// Uses WhisperKit as the transcription provider with automatic language detection
    /// and no AI enhancement enabled.
    static let defaultMode = VivaMode(
        id: UUID(),
        name: "Default",
        transcriptionProvider: .whisperKit,
        transcriptionModel: "",
        transcriptionLanguage: "auto",
        userPrompt: nil,
        aiModel: "",
        aiEnhanceEnabled: false)
}
