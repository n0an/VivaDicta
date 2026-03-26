//
//  LoggerExtension.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.16
//

import Foundation
import os

/// Centralized log categories for the VivaDicta app
public enum LogCategory: String {
    // MARK: - App Core
    case app = "VivaDictaApp"
    case appDelegate = "AppDelegate"
    case sceneDelegate = "SceneDelegate"
    case appState = "AppState"

    // MARK: - Views
    case mainView = "MainView"
    case recordViewModel = "RecordViewModel"
    case transcriptionsContentView = "TranscriptionsContentView"
    case audioPlayerManager = "AudioPlayerManager"
    case modeEditViewModel = "ModeEditViewModel"

    // MARK: - Services - Transcription
    case transcriptionManager = "TranscriptionManager"
    case whisperKitTranscriptionService = "WhisperKitTranscriptionService"
    case parakeetTranscriptionService = "ParakeetTranscriptionService"
    case transcriptionOutputFilter = "TranscriptionOutputFilter"

    // MARK: - Services - Cloud Transcription
    case openAITranscriptionService = "OpenAITranscriptionService"
    case elevenLabsTranscriptionService = "ElevenLabsTranscriptionService"
    case groqTranscriptionService = "GroqTranscriptionService"
    case deepgramService = "DeepgramService"
    case geminiService = "GeminiService"
    case mistralTranscriptionService = "MistralTranscriptionService"
    case sonioxTranscriptionService = "SonioxTranscriptionService"
    case customTranscriptionService = "CustomTranscriptionService"

    // MARK: - Services - Other
    case aiService = "AIService"
    case modelDownloadManager = "ModelDownloadManager"
    case audioPrewarmManager = "AudioPrewarmManager"
    case appGroupCoordinator = "AppGroupCoordinator"
    case promptsManager = "PromptsManager"
    case customVocabulary = "CustomVocabulary"
    case replacementsService = "ReplacementsService"
    case dictionaryMigration = "DictionaryMigration"
    case variationMigration = "VariationMigration"
    case presetManager = "PresetManager"
    case presetMigration = "PresetMigration"
    case presetSync = "PresetSync"
    case keychainService = "KeychainService"
    case oauthManager = "OAuthManager"
    case chatGPTAPI = "ChatGPTAPIClient"
    case geminiOAuthAPI = "GeminiAPIClient"

    // MARK: - Keyboard Extension
    case keyboardExtension = "KeyboardExtension"
    case vivaModeManager = "VivaModeManager"

    // MARK: - Utility
    case installInputTapNonisolated = "installInputTapNonisolated"
}

/// The app's subsystem identifier for all loggers
/// Using the main app bundle ID for consistency across main app and extensions
private nonisolated(unsafe) let kLoggingSubsystem = "com.antonnovoselov.VivaDicta"

public extension Logger {
    /// Creates a Logger with the app's bundle identifier as subsystem and the specified category
    /// - Parameter category: The log category enum value
    nonisolated init(category: LogCategory) {
        self.init(subsystem: kLoggingSubsystem, category: category.rawValue)
    }

    /// Check if print logs are enabled via environment variable
    private nonisolated static var printLogsEnabled: Bool {
        ProcessInfo.processInfo.environment["ENABLE_PRINT_LOGS"] == "1"
    }

    /// Log info level with optional print statement
    nonisolated func logInfo(_ message: String) {
        self.info("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log debug level with optional print statement
    nonisolated func logDebug(_ message: String) {
        self.debug("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log error level with optional print statement
    nonisolated func logError(_ message: String) {
        self.error("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log warning level with optional print statement
    nonisolated func logWarning(_ message: String) {
        self.warning("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log notice level with optional print statement
    nonisolated func logNotice(_ message: String) {
        self.notice("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }
}

struct SignpostLog {
    static var pointsOfInterest: OSLog {
        if ProcessInfo.processInfo.environment["SIGNPOST_ENABLED"] == "1" {
            return OSLog(subsystem: kLoggingSubsystem, category: .pointsOfInterest)
        } else {
            return .disabled
        }
    }
    
    static var general: OSLog {
        if ProcessInfo.processInfo.environment["SIGNPOST_ENABLED"] == "1" {
            return OSLog(subsystem: kLoggingSubsystem, category: "general")
        } else {
            return .disabled
        }
    }
}
