//
//  VivaMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI
import AppGroup
import AICore

/// A configuration preset combining transcription and AI processing settings.
///
/// `VivaMode` encapsulates all settings needed for a complete transcription workflow,
/// including which transcription model to use, which AI provider to enhance with,
/// and the preset to guide enhancement.
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
/// - ``aiEnhanceEnabled``: Whether to apply AI processing
/// - ``aiProvider``: Which AI provider to use (OpenAI, Anthropic, etc.)
/// - ``aiModel``: The specific AI model name
/// - ``presetId``: ID of the preset guiding enhancement
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

    /// Target language for inline translation during transcription (Soniox, Gladia, Speechmatics).
    /// `nil` or empty means no translation; otherwise a 2-letter language code (e.g. "en").
    let translationTargetLanguage: String?

    /// ID of the preset for AI processing, if any.
    let presetId: String?

    /// The AI provider for text enhancement.
    var aiProvider: AIProvider?

    /// The specific AI model name for enhancement.
    var aiModel: String

    /// Optional provider override used only for reminder suggestion extraction.
    var reminderExtractorProvider: AIProvider?

    /// Optional model override used only for reminder suggestion extraction.
    var reminderExtractorModel: String?

    /// Whether AI processing is enabled for this mode.
    let aiEnhanceEnabled: Bool

    /// Whether clipboard content should be captured and used as context for AI processing.
    let useClipboardContext: Bool

    /// Whether automatic text formatting (paragraph splitting) is applied after transcription and AI processing.
    let isAutoTextFormattingEnabled: Bool

    /// Whether smart insert (auto-adjust spacing and capitalization) is applied when inserting text via keyboard.
    let isSmartInsertEnabled: Bool

    /// Whether this mode opts in to saving transcriptions to Obsidian.
    /// Only effective when the global Obsidian integration is enabled in
    /// Settings → Integrations.
    var obsidianEnabled: Bool

    /// Whether this mode opts in to silently saving each transcription as a
    /// markdown file in the user-picked folder. Only effective when the
    /// global folder-export integration is enabled in Settings → Integrations.
    var folderExportEnabled: Bool

    /// Creates a new VivaMode with the specified settings.
    init(id: UUID,
         name: String,
         transcriptionProvider: TranscriptionModelProvider,
         transcriptionModel: String,
         transcriptionLanguage: String? = nil,
         translationTargetLanguage: String? = nil,
         presetId: String? = nil,
         aiProvider: AIProvider? = nil,
         aiModel: String,
         reminderExtractorProvider: AIProvider? = nil,
         reminderExtractorModel: String? = nil,
         aiEnhanceEnabled: Bool,
         useClipboardContext: Bool = false,
         isAutoTextFormattingEnabled: Bool = false,
         isSmartInsertEnabled: Bool = false,
         obsidianEnabled: Bool = true,
         folderExportEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguage = transcriptionLanguage
        self.translationTargetLanguage = translationTargetLanguage
        self.presetId = presetId
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.reminderExtractorProvider = reminderExtractorProvider
        self.reminderExtractorModel = reminderExtractorModel
        self.aiEnhanceEnabled = aiEnhanceEnabled
        self.useClipboardContext = useClipboardContext
        self.isAutoTextFormattingEnabled = isAutoTextFormattingEnabled
        self.isSmartInsertEnabled = isSmartInsertEnabled
        self.obsidianEnabled = obsidianEnabled
        self.folderExportEnabled = folderExportEnabled
    }

    // MARK: - Backward-Compatible Decoding

    /// Supports decoding both old format (with `userPrompt`) and new format (with `presetId`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        transcriptionProvider = try container.decode(TranscriptionModelProvider.self, forKey: .transcriptionProvider)
        let decodedTranscriptionModel = try container.decode(String.self, forKey: .transcriptionModel)
        transcriptionModel = VivaMode.normalizedTranscriptionModelID(decodedTranscriptionModel, provider: transcriptionProvider)
        transcriptionLanguage = try container.decodeIfPresent(String.self, forKey: .transcriptionLanguage)
        translationTargetLanguage = try container.decodeIfPresent(String.self, forKey: .translationTargetLanguage)
        aiProvider = try container.decodeIfPresent(AIProvider.self, forKey: .aiProvider)
        let decodedAIModel = try container.decode(String.self, forKey: .aiModel)
        aiModel = VivaMode.normalizedModelID(decodedAIModel, provider: aiProvider)
        let decodedReminderProvider = try container.decodeIfPresent(AIProvider.self, forKey: .reminderExtractorProvider)
        reminderExtractorProvider = decodedReminderProvider
        if let decodedReminderModel = try container.decodeIfPresent(String.self, forKey: .reminderExtractorModel) {
            reminderExtractorModel = VivaMode.normalizedModelID(decodedReminderModel, provider: decodedReminderProvider)
        } else {
            reminderExtractorModel = nil
        }
        aiEnhanceEnabled = try container.decode(Bool.self, forKey: .aiEnhanceEnabled)
        useClipboardContext = try container.decodeIfPresent(Bool.self, forKey: .useClipboardContext) ?? false
        isAutoTextFormattingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoTextFormattingEnabled) ?? true
        isSmartInsertEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSmartInsertEnabled) ?? true
        obsidianEnabled = try container.decodeIfPresent(Bool.self, forKey: .obsidianEnabled) ?? true
        folderExportEnabled = try container.decodeIfPresent(Bool.self, forKey: .folderExportEnabled) ?? true

        // Try new format first
        if let preset = try container.decodeIfPresent(String.self, forKey: .presetId) {
            presetId = preset
        } else if container.contains(.userPrompt) {
            // Fall back to old format: decode embedded UserPrompt and preserve its title as the preset ID
            let legacyPrompt = try container.decodeIfPresent(LegacyUserPrompt.self, forKey: .userPrompt)
            // Lowercase so legacy display titles ("Regular") map to built-in preset IDs ("regular")
            presetId = legacyPrompt?.title.lowercased()
        } else {
            presetId = nil
        }
    }

    // MARK: - Model ID Normalization

    /// Rewrites retired or renamed model IDs to their current replacements on decode,
    /// so users who picked a model that has since been removed from `AIProvider.availableModels`
    /// or `GeminiAPIClient.supportedModels` don't end up with a blank picker or a 404.
    ///
    /// Add new entries here whenever a model is removed from the available lists.
    /// Mirror Google's deprecation table for Gemini.
    static func normalizedModelID(_ modelID: String, provider: AIProvider?) -> String {
        guard provider == .gemini else { return modelID }
        switch modelID {
        case "gemini-3-pro-preview":
            // Retired by Google; superseded by gemini-3.1-pro-preview.
            return "gemini-3.1-pro-preview"
        default:
            return modelID
        }
    }

    /// Same rewrite logic as `normalizedModelID(_:provider:)` but for the transcription model.
    /// Without this, a saved mode pinned to a retired transcription model would fail
    /// `TranscriptionManager.getCurrentTranscriptionModel()`'s exact lookup in `allCloudModels`
    /// and the user would get `TranscriptionError.transcriptionFailed` before any network call.
    static func normalizedTranscriptionModelID(_ modelID: String, provider: TranscriptionModelProvider) -> String {
        guard provider == .gemini else { return modelID }
        switch modelID {
        case "gemini-3-pro-preview":
            return "gemini-3.1-pro-preview"
        default:
            return modelID
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, transcriptionProvider, transcriptionModel, transcriptionLanguage
        case translationTargetLanguage
        case presetId, userPrompt
        case aiProvider, aiModel, reminderExtractorProvider, reminderExtractorModel, aiEnhanceEnabled
        case useClipboardContext
        case isAutoTextFormattingEnabled, isSmartInsertEnabled
        case obsidianEnabled
        case folderExportEnabled
    }

    /// Encodes using the new format only (presetId).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(transcriptionProvider, forKey: .transcriptionProvider)
        try container.encode(transcriptionModel, forKey: .transcriptionModel)
        try container.encodeIfPresent(transcriptionLanguage, forKey: .transcriptionLanguage)
        try container.encodeIfPresent(translationTargetLanguage, forKey: .translationTargetLanguage)
        try container.encodeIfPresent(presetId, forKey: .presetId)
        try container.encodeIfPresent(aiProvider, forKey: .aiProvider)
        try container.encode(aiModel, forKey: .aiModel)
        try container.encodeIfPresent(reminderExtractorProvider, forKey: .reminderExtractorProvider)
        try container.encodeIfPresent(reminderExtractorModel, forKey: .reminderExtractorModel)
        try container.encode(aiEnhanceEnabled, forKey: .aiEnhanceEnabled)
        try container.encode(useClipboardContext, forKey: .useClipboardContext)
        try container.encode(isAutoTextFormattingEnabled, forKey: .isAutoTextFormattingEnabled)
        try container.encode(isSmartInsertEnabled, forKey: .isSmartInsertEnabled)
        try container.encode(obsidianEnabled, forKey: .obsidianEnabled)
        try container.encode(folderExportEnabled, forKey: .folderExportEnabled)
    }

    /// The default mode used when no custom mode is configured.
    ///
    /// Uses WhisperKit as the transcription provider with automatic language detection
    /// and no AI processing enabled.
    static let defaultMode = VivaMode(
        id: UUID(),
        name: "Default",
        transcriptionProvider: .whisperKit,
        transcriptionModel: "",
        transcriptionLanguage: "auto",
        presetId: nil,
        aiModel: "",
        aiEnhanceEnabled: false)
}

/// Minimal struct for decoding legacy UserPrompt data embedded in old VivaModes.
/// Only used during backward-compatible decoding.
private struct LegacyUserPrompt: Codable {
    let id: UUID
    let title: String
    let promptInstructions: String
    let useSystemTemplate: Bool
    let wrapInTranscriptTags: Bool?
    let createdAt: Date
}
