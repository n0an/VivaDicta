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
    case transcriptionDetailView = "TranscriptionDetailView"
    case audioPlayerManager = "AudioPlayerManager"
    case modeEditViewModel = "ModeEditViewModel"

    // MARK: - Services - Transcription
    case transcriptionManager = "TranscriptionManager"
    case transcriptionOutputFilter = "TranscriptionOutputFilter"

    // MARK: - Services - Cloud Transcription
    case openAITranscriptionService = "OpenAITranscriptionService"
    case elevenLabsTranscriptionService = "ElevenLabsTranscriptionService"
    case groqTranscriptionService = "GroqTranscriptionService"
    case deepgramService = "DeepgramService"
    case geminiService = "GeminiService"
    case mistralTranscriptionService = "MistralTranscriptionService"
    case sonioxTranscriptionService = "SonioxTranscriptionService"
    case gladiaTranscriptionService = "GladiaTranscriptionService"
    case speechmaticsTranscriptionService = "SpeechmaticsTranscriptionService"
    case cohereTranscriptionService = "CohereTranscriptionService"
    case cartesiaTranscriptionService = "CartesiaTranscriptionService"
    case customTranscriptionService = "CustomTranscriptionService"
    case sonioxRealtimeDictation = "SonioxRealtimeDictation"
    case deepgramFluxRealtimeDictation = "DeepgramFluxRealtimeDictation"
    case deepgramNovaRealtimeDictation = "DeepgramNovaRealtimeDictation"
    case elevenLabsRealtimeDictation = "ElevenLabsRealtimeDictation"
    case mistralRealtimeDictation = "MistralRealtimeDictation"
    case cartesiaRealtimeDictation = "CartesiaRealtimeDictation"
    case geminiLiveRealtimeDictation = "GeminiLiveRealtimeDictation"
    case streamingAudioCapture = "StreamingAudioCapture"

    // MARK: - Services - Live Translation
    case liveTranslationService = "LiveTranslationService"
    case liveTranslationSTT = "LiveTranslationSTT"
    case liveTranslationTTS = "LiveTranslationTTS"
    case liveTranslationAudio = "LiveTranslationAudio"

    // MARK: - Services - Other
    case aiService = "AIService"
    case modelDownloadManager = "ModelDownloadManager"
    case audioPrewarmManager = "AudioPrewarmManager"
    case promptsManager = "PromptsManager"
    case customVocabulary = "CustomVocabulary"
    case replacementsService = "ReplacementsService"
    case variationMigration = "VariationMigration"
    case presetManager = "PresetManager"
    case presetSync = "PresetSync"
    case keychainService = "KeychainService"
    case openAIOAuthAPI = "OpenAIOAuthClient"
    case geminiOAuthAPI = "GeminiAPIClient"
    case copilotAPI = "CopilotAPIClient"
    case vivAgentsClient = "VivAgentsClient"
    case chatViewModel = "ChatViewModel"
    case multiNoteChat = "MultiNoteChat"
    case ragIndexing = "RAGIndexing"
    case ragSearch = "RAGSearch"
    case smartSearchChat = "SmartSearchChat"
    case reminderExtraction = "ReminderExtraction"
    case remindersImport = "RemindersImport"
    case calendarImport = "CalendarImport"

    // MARK: - Watch Connectivity
    case watchConnectivity = "WatchConnectivity"

    // MARK: - Analytics
    case analytics = "Analytics"

    // MARK: - Background Tasks
    case backgroundTask = "BackgroundTask"

    // MARK: - Keyboard Extension
    case keyboardExtension = "KeyboardExtension"
    case vivaModeManager = "VivaModeManager"

    // MARK: - Utility
    case installInputTapNonisolated = "installInputTapNonisolated"
    case folderExportService = "FolderExportService"
}

/// The app's subsystem identifier for all loggers
/// Using the main app bundle ID for consistency across main app and extensions
private nonisolated let kLoggingSubsystem = "com.antonnovoselov.VivaDicta"

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

    /// Wall-clock stamp for the print mirror.
    ///
    /// `devicectl --console` streams stdout, which carries none of the unified
    /// log's metadata, so the time has to be part of the message itself.
    private nonisolated static let printTimestampStyle = Date.VerbatimFormatStyle(
        format: """
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\
            \(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))
            """,
        timeZone: .current,
        calendar: .current
    )

    // Why no `isEnabled(type:)` level check before logging
    //
    // `Logger.isEnabled(type:)` only appeared in the iOS 26 SDK, but Apple
    // annotated it with `Logger`'s own `@available(iOS 14.0, *)`. The compiler
    // therefore binds it strongly instead of weak-importing it, and iOS 18's
    // `libswiftos.dylib` does not export it - dyld aborts the process at launch
    // with "Symbol not found: os.Logger.isEnabled(type:)". An `#available`
    // guard does not help: the bind happens before any of our code runs.
    // `os_log` performs its own level check internally, so the only cost of
    // dropping the guard is building the message string.

    /// Mirrors one message to stdout so a device console capture can read it.
    ///
    /// Unified logging records the subsystem but not the call site, and stdout
    /// records nothing at all, so level, time and origin are written into the
    /// line. Format: `18:06:04.357 [INFO] VivaDicta/AIService.swift:854 message`
    private nonisolated static func mirrorToPrint(
        _ level: String,
        _ message: String,
        _ fileID: String,
        _ line: Int
    ) {
        print("\(Date.now.formatted(printTimestampStyle)) [\(level)] \(fileID):\(line) \(message)")
    }

    /// Log info level with optional print statement
    nonisolated func logInfo(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: Int = #line
    ) {
        let mirroring = Self.printLogsEnabled
        let text = message()
        self.info("\(text, privacy: .public)")

        if mirroring {
            Self.mirrorToPrint("INFO", text, fileID, line)
        }
    }

    /// Log debug level with optional print statement
    nonisolated func logDebug(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: Int = #line
    ) {
        let mirroring = Self.printLogsEnabled
        let text = message()
        self.debug("\(text, privacy: .public)")

        if mirroring {
            Self.mirrorToPrint("DEBUG", text, fileID, line)
        }
    }

    /// Log error level with optional print statement
    nonisolated func logError(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: Int = #line
    ) {
        let mirroring = Self.printLogsEnabled
        let text = message()
        self.error("\(text, privacy: .public)")

        if mirroring {
            Self.mirrorToPrint("ERROR", text, fileID, line)
        }
    }

    /// Log warning level with optional print statement
    nonisolated func logWarning(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: Int = #line
    ) {
        let mirroring = Self.printLogsEnabled
        let text = message()
        self.warning("\(text, privacy: .public)")

        if mirroring {
            Self.mirrorToPrint("WARN", text, fileID, line)
        }
    }

    /// Log notice level with optional print statement
    nonisolated func logNotice(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: Int = #line
    ) {
        let mirroring = Self.printLogsEnabled
        let text = message()
        self.notice("\(text, privacy: .public)")

        if mirroring {
            Self.mirrorToPrint("NOTICE", text, fileID, line)
        }
    }
}

