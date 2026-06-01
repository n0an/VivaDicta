//
//  UserDefaultsStorage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

/// A wrapper for UserDefaults that explicitly declares storage intent
public enum UserDefaultsStorage {
    /// For data that MUST be shared between app and extensions
    /// Examples: Flow modes, API keys, transcription settings, selected modes
    public static var shared: UserDefaults {
        UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)!
    }

    /// For app-private data that extensions don't need
    /// Examples: UI state, onboarding flags, debug settings, analytics
    public static var appPrivate: UserDefaults {
        UserDefaults.standard
    }

    // MARK: - Shared Keys (used by main app + extensions)

    public enum SharedKeys {
        public static let presets = "Presets_v1"
        public static let hiddenPresetIDs = "HiddenPresetIDs_v1"

        /// Security-scoped bookmark Data for the user-picked folder export destination.
        /// Lives in the App Group so the keyboard extension can resolve it.
        public static let folderExportBookmark = "folderExportBookmark"

        /// Display name of the folder picked for export. Shared so the keyboard
        /// extension can also read it (kept symmetric with the bookmark Data).
        public static let folderExportDisplayName = "folderExportDisplayName"
    }

    // MARK: - App-Private Keys

    public enum Keys {
        public static let appLaunchCount = "appLaunchCount"
        public static let firstLaunchDate = "firstLaunchDate"
        public static let lastRatingRequestDate = "lastRatingRequestDate"
        public static let hasCompletedOnboarding = "hasCompletedOnboarding"
        public static let didTapOpenSettingsInOnboarding = "didTapOpenSettingsInOnboarding"
        public static let audioSessionTimeout = "audioSessionTimeout"
        public static let isTextFormattingEnabled = "IsTextFormattingEnabled"
        public static let displaySiriTip = "displaySiriTip"
        public static let customVocabularyWords = "customVocabularyWords"
        public static let textReplacements = "textReplacements"
        public static let isReplacementsEnabled = "isReplacementsEnabled"
        public static let isSpellingCorrectionsEnabled = "isSpellingCorrectionsEnabled"
        public static let isParakeetVocabularyBoostingEnabled = "isParakeetVocabularyBoostingEnabled"
        public static let isAutoAudioCleanupEnabled = "isAutoAudioCleanupEnabled"
        public static let audioRetentionDays = "audioRetentionDays"
        public static let isAutoNoteCleanupEnabled = "isAutoNoteCleanupEnabled"
        public static let noteRetentionDays = "noteRetentionDays"
        public static let isAutoChatCleanupEnabled = "isAutoChatCleanupEnabled"
        public static let chatRetentionDays = "chatRetentionDays"
        public static let openRouterModels = "openRouterModels"
        public static let vercelAIGatewayModels = "vercelAIGatewayModels"
        public static let huggingFaceModels = "huggingFaceModels"
        public static let ollamaModels = "ollamaModels"
        public static let ollamaServerURL = "ollamaServerURL"
        public static let ollamaCloudModels = "ollamaCloudModels"

        // iCloud
        public static let isICloudSyncEnabled = "isICloudSyncEnabled"

        // Auto-copy
        public static let isAutoCopyAfterRecordingEnabled = "isAutoCopyAfterRecordingEnabled"
        public static let isAutoReminderExtractionEnabled = "isAutoReminderExtractionEnabled"

        // Custom OpenAI Provider Configuration
        public static let customOpenAIEndpointURL = "customOpenAIEndpointURL"
        public static let customOpenAIModelName = "customOpenAIModelName"
        public static let customOpenAIIsVerified = "customOpenAIIsVerified"
        public static let isImplicitCrossNoteSearchEnabled = "isImplicitCrossNoteSearchEnabled"
        public static let isImplicitWebSearchEnabled = "isImplicitWebSearchEnabled"

        // First-launch auto-assignment
        public static let didAutoAssignCloudTranscription = "didAutoAssignCloudTranscription"

        // What's New
        public static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"

        // Recording sheet visualization
        public static let recordingOrbStyle = "recordingOrbStyle"

        // Advanced settings
        public static let appendWithVoiceStyle = "appendWithVoiceStyle"
        public static let isChatEnabled = "isChatEnabled"
        public static let isLiveTranslationEnabled = "isLiveTranslationEnabled"
        public static let isStripTrailingPeriodEnabled = "isStripTrailingPeriodEnabled"

        /// UUID string of the mode used for AI actions in note detail when the
        /// currently selected mode has no AI processing configured. Empty = none.
        public static let defaultAIModeId = "defaultAIModeId"

        // Notes filter
        public static let savedNotesFilterSourceTags = "savedNotesFilterSourceTags"
        public static let savedNotesFilterUserTagIds = "savedNotesFilterUserTagIds"

        // Integrations - Obsidian
        public static let isObsidianGloballyEnabled = "isObsidianGloballyEnabled"
        public static let obsidianNoteTemplate = "obsidianNoteTemplate"
        public static let isObsidianSendButtonEnabled = "isObsidianSendButtonEnabled"

        // Integrations - Folder export (silent markdown save to user-picked folder)
        public static let isFolderExportGloballyEnabled = "isFolderExportGloballyEnabled"
        public static let isFolderExportButtonEnabled = "isFolderExportButtonEnabled"

        // Live Translation
        public static let liveTranslationSourceLanguage = "liveTranslation.sourceLanguage"
        public static let liveTranslationTargetLanguage = "liveTranslation.targetLanguage"
        public static let liveTranslationTTSEnabled = "liveTranslation.ttsEnabled"
        public static let liveTranslationTTSRate = "liveTranslation.ttsRate"
        public static let liveTranslationTTSVoice = "liveTranslation.ttsVoice"
    }

    // MARK: - Integrations defaults

    public static let defaultObsidianNoteTemplate = "VD {date} {HH}-{mm}-{ss}"
}
