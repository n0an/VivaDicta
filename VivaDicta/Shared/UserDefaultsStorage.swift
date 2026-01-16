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

    // MARK: - App-Private Keys

    enum Keys {
        static let appLaunchCount = "appLaunchCount"
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
        static let openRouterModels = "openRouterModels"
    }
}
