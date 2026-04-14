//
//  UserDefaultsStorage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

/// A wrapper for UserDefaults that explicitly declares storage intent
enum UserDefaultsStorage {
    /// For data that MUST be shared between app and extensions
    /// Examples: Flow modes, API keys, transcription settings, selected modes
    static var shared: UserDefaults {
        UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)!
    }

    /// For app-private data that extensions don't need
    /// Examples: UI state, onboarding flags, debug settings, analytics
    static var appPrivate: UserDefaults {
        UserDefaults.standard
    }

    // MARK: - Shared Keys (used by main app + extensions)

    enum SharedKeys {
        static let presets = "Presets_v1"
        static let hiddenPresetIDs = "HiddenPresetIDs_v1"
    }

    // MARK: - App-Private Keys

    enum Keys {
        static let appLaunchCount = "appLaunchCount"
        static let firstLaunchDate = "firstLaunchDate"
        static let lastRatingRequestDate = "lastRatingRequestDate"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let didTapOpenSettingsInOnboarding = "didTapOpenSettingsInOnboarding"
        static let audioSessionTimeout = "audioSessionTimeout"
        static let isTextFormattingEnabled = "IsTextFormattingEnabled"
        static let displaySiriTip = "displaySiriTip"
        static let customVocabularyWords = "customVocabularyWords"
        static let textReplacements = "textReplacements"
        static let isReplacementsEnabled = "isReplacementsEnabled"
        static let isSpellingCorrectionsEnabled = "isSpellingCorrectionsEnabled"
        static let isAutoAudioCleanupEnabled = "isAutoAudioCleanupEnabled"
        static let audioRetentionDays = "audioRetentionDays"
        static let isAutoNoteCleanupEnabled = "isAutoNoteCleanupEnabled"
        static let noteRetentionDays = "noteRetentionDays"
        static let isAutoChatCleanupEnabled = "isAutoChatCleanupEnabled"
        static let chatRetentionDays = "chatRetentionDays"
        static let openRouterModels = "openRouterModels"
        static let vercelAIGatewayModels = "vercelAIGatewayModels"
        static let huggingFaceModels = "huggingFaceModels"
        static let ollamaModels = "ollamaModels"
        static let ollamaServerURL = "ollamaServerURL"

        // iCloud
        static let isICloudSyncEnabled = "isICloudSyncEnabled"

        // Auto-copy
        static let isAutoCopyAfterRecordingEnabled = "isAutoCopyAfterRecordingEnabled"

        // Custom OpenAI Provider Configuration
        static let customOpenAIEndpointURL = "customOpenAIEndpointURL"
        static let customOpenAIModelName = "customOpenAIModelName"
        static let customOpenAIIsVerified = "customOpenAIIsVerified"

        // First-launch auto-assignment
        static let didAutoAssignCloudTranscription = "didAutoAssignCloudTranscription"

        // What's New
        static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"

        // Notes filter
        static let savedNotesFilterSourceTags = "savedNotesFilterSourceTags"
        static let savedNotesFilterUserTagIds = "savedNotesFilterUserTagIds"
    }
}
