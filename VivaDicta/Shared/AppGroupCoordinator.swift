//
//  AppGroupCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.03
//



@preconcurrency import Foundation
import os


/// Coordinates communication between the main app and extensions (keyboard, share, widget).
///
/// `AppGroupCoordinator` uses App Groups for shared storage and Darwin Notifications
/// for real-time event communication. It manages the bidirectional communication
/// needed for features like keyboard-initiated recording.
///
/// ## Overview
///
/// The coordinator handles:
/// - Recording commands (start, stop, cancel, pause, resume) from keyboard extension
/// - Transcription status updates (transcribing, enhancing, completed, error)
/// - Audio level sharing for remote visualization
/// - Keyboard session lifecycle management
/// - Transcribed text delivery back to keyboard
/// - VivaMode sharing between app and extensions
///
/// ## App Group
///
/// Uses the shared container `group.com.antonnovoselov.VivaDicta` for UserDefaults
/// and file storage accessible by all app extensions.
///
/// ## Darwin Notifications
///
/// Real-time events are communicated via Darwin notifications, which work across
/// process boundaries without requiring the target to be running.
///
/// ## Usage
///
/// ```swift
/// // From keyboard extension - request recording
/// AppGroupCoordinator.shared.requestStartRecording()
///
/// // From main app - listen for requests
/// AppGroupCoordinator.shared.onStartRecordingRequested = {
///     self.startRecording()
/// }
/// ```
public final class AppGroupCoordinator {
    public static let shared = AppGroupCoordinator()

    private let logger = Logger(category: .appGroupCoordinator)

    
    // MARK: - Constants
    public let appGroupId = "group.com.antonnovoselov.VivaDicta"
    // AI Processing configuration
    public static let vivaModesKey = "VivaModes"
    public static let selectedVivaModeKey = "selectedVivaMode"
    public static let kSelectedLanguageKey = "selectedLanguageKey"
    public static let kAPIKeyTemplate = "apiKeyTemplate"
    public static let kSmartFormattingOnPaste = "smartFormattingOnPaste"
    public static let kKeepTranscriptInClipboard = "keepTranscriptInClipboard"
    public static let kIsVADEnabled = "IsVADEnabled"
    public static let kIsKeyboardHapticFeedbackEnabled = "isKeyboardHapticFeedbackEnabled"
    public static let kIsKeyboardSoundFeedbackEnabled = "isKeyboardSoundFeedbackEnabled"
    
    public static let isHapticsEnabled = "isHapticsEnabled"

    // Share Extension
    public static let kPendingSharedAudioFileName = "pendingSharedAudioFileName"
    public static let kPendingLanguageOverride = "pendingLanguageOverride"


    nonisolated private enum UserDefaultsKeys {
        static let isRecording = "isRecording"
        static let lastRecordingTimestamp = "lastRecordingTimestamp"
        static let transcribedText = "transcribedText"
        static let transcriptionStatus = "transcriptionStatus"
        static let keyboardSessionActive = "keyboardSessionActive"
        static let keyboardSessionExpiryTime = "keyboardSessionExpiryTime"
        static let audioLevel = "audioLevel" // 0.0 ... 1.0
        static let transcriptionErrorMessage = "transcriptionErrorMessage"
        static let keyboardClipboardContext = "keyboardClipboardContext"
    }

    nonisolated private enum NotificationNames {
        static let startRecording = "com.antonnovoselov.VivaDicta.startRecording"
        static let stopRecording = "com.antonnovoselov.VivaDicta.stopRecording"
        static let cancelRecording = "com.antonnovoselov.VivaDicta.cancelRecording"
        static let pauseRecording = "com.antonnovoselov.VivaDicta.pauseRecording"
        static let resumeRecording = "com.antonnovoselov.VivaDicta.resumeRecording"
        static let recordingStateChanged = "com.antonnovoselov.VivaDicta.recordingStateChanged"
        static let transcriptionCompleted = "com.antonnovoselov.VivaDicta.transcriptionCompleted"
        static let keyboardSessionActivated = "com.antonnovoselov.VivaDicta.keyboardSessionActivated"
        static let keyboardSessionExpired = "com.antonnovoselov.VivaDicta.keyboardSessionExpired"
        static let transcriptionTranscribing = "com.antonnovoselov.VivaDicta.transcriptionTranscribing"
        static let transcriptionEnhancing = "com.antonnovoselov.VivaDicta.transcriptionEnhancing"
        static let transcriptionError = "com.antonnovoselov.VivaDicta.transcriptionError"
        static let transcriptionCancelled = "com.antonnovoselov.VivaDicta.transcriptionCancelled"
        static let audioLevelUpdated = "com.antonnovoselov.VivaDicta.audioLevelUpdated"
        static let startRecordingFromControl = "com.antonnovoselov.VivaDicta.startRecordingFromControl"
        static let terminateSessionFromLiveActivity = "com.antonnovoselov.VivaDicta.terminateSessionFromLiveActivity"
        static let vivaModeChanged = "com.antonnovoselov.VivaDicta.vivaModeChanged"
    }

    /// Status of the transcription pipeline, shared with extensions.
    public enum TranscriptionStatus: String {
        case idle = "idle"
        case recording = "recording"
        case transcribing = "transcribing"
        case enhancing = "AI processing"
        case completed = "completed"
        case error = "error"
    }

    // MARK: - Properties
    private let sharedDefaults: UserDefaults?
    nonisolated private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    @MainActor var onStartRecordingRequested: (() -> Void)?
    @MainActor var onStopRecordingRequested: (() -> Void)?
    @MainActor var onCancelRecordingRequested: (() -> Void)?
    @MainActor var onPauseRecordingRequested: (() -> Void)?
    @MainActor var onResumeRecordingRequested: (() -> Void)?
    @MainActor var onKeyboardSessionActivated: (() -> Void)?
    @MainActor var onTranscriptionCompleted: ((String) -> Void)?
    @MainActor var onTranscriptionTranscribing: (() -> Void)?
    @MainActor var onTranscriptionEnhancing: (() -> Void)?
    @MainActor var onTranscriptionError: (() -> Void)?
    @MainActor var onTranscriptionCancelled: (() -> Void)?
    @MainActor var onTranscriptionErrorMessage: ((String) -> Void)?
    @MainActor var onKeyboardSessionExpired: (() -> Void)?
    @MainActor var onAudioLevelUpdated: ((CGFloat) -> Void)?
    @MainActor var onRecordingStateChanged: ((Bool) -> Void)?
    @MainActor var onStartRecordingFromControl: (() -> Void)?
    @MainActor var onTerminateSessionFromLiveActivity: (() -> Void)?
    @MainActor var onVivaModeChanged: (() -> Void)?

    // MARK: - Initialization
    private init() {
        sharedDefaults = UserDefaults(suiteName: appGroupId)
        setupNotificationObservers()
    }

    nonisolated deinit {
        removeNotificationObservers()
    }

    // MARK: - App Launch State Management

    /// Reset session state on app launch to prevent stale state issues
    func resetSessionStateOnAppLaunch() {
        sharedDefaults?.set(false, forKey: UserDefaultsKeys.keyboardSessionActive)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
        sharedDefaults?.set(false, forKey: UserDefaultsKeys.isRecording)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.transcribedText)
        updateTranscriptionStatus(.idle)

        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.audioLevel)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.transcriptionErrorMessage)

        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.lastRecordingTimestamp)

        logger.logError("🧹 Complete session state reset on app launch - fresh start")
    }

    // MARK: - Public Interface for Keyboard Extension

    /// Requests the main app to start recording (called from keyboard extension).
    public func requestStartRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.startRecording)
    }

    public func requestStartRecordingFromControl() {
        postDarwinNotification(NotificationNames.startRecordingFromControl)
    }

    /// Requests the main app to stop recording and begin transcription.
    public func requestStopRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.stopRecording)
    }

    /// Requests the main app to cancel the current recording or transcription.
    public func requestCancelRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.cancelRecording)
    }

    public func requestTerminateSessionFromLiveActivity() {
        postDarwinNotification(NotificationNames.terminateSessionFromLiveActivity)
        logger.logError("📡 Requested session termination from Live Activity")
    }

    var isRecording: Bool {
        let storedState = sharedDefaults?.bool(forKey: UserDefaultsKeys.isRecording) ?? false
        let timestamp = sharedDefaults?.double(forKey: UserDefaultsKeys.lastRecordingTimestamp) ?? 0
        let currentTime = Date().timeIntervalSince1970

        if storedState && (currentTime - timestamp) > 30 && !isKeyboardSessionActive {
            logger.logError("⚠️ Recording state appears stale, clearing it")
            updateRecordingState(false)
            return false
        }

        return storedState
    }

    // MARK: - Public Interface for Main App

    func updateRecordingState(_ isRecording: Bool) {
        sharedDefaults?.set(isRecording, forKey: UserDefaultsKeys.isRecording)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.recordingStateChanged)
        logger.logError("📡 Updated recording state: \(isRecording)")
    }

    // MARK: - Audio Level Sharing
    func updateAudioLevel(_ level: CGFloat) {
        let clamped = max(0, min(1, level))
        sharedDefaults?.set(Double(clamped), forKey: UserDefaultsKeys.audioLevel)
        postDarwinNotification(NotificationNames.audioLevelUpdated)
    }

    var currentAudioLevel: CGFloat {
        let value = sharedDefaults?.double(forKey: UserDefaultsKeys.audioLevel) ?? 0
        return CGFloat(max(0, min(1, value)))
    }

    // MARK: - Keyboard Dictation Session Management

    /// Activates a keyboard recording session with the specified timeout.
    ///
    /// - Parameter timeoutSeconds: How long the session remains active without activity.
    func activateKeyboardSession(timeoutSeconds: Int) {
        let expiryTime = Date().timeIntervalSince1970 + Double(timeoutSeconds)
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.keyboardSessionActive)
        sharedDefaults?.set(expiryTime, forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.keyboardSessionActivated)
        logger.logError("🔑 Keyboard session activated for \(timeoutSeconds) seconds")
    }

    var isKeyboardSessionActive: Bool {
        guard let defaults = sharedDefaults else { return false }

        let isActive = defaults.bool(forKey: UserDefaultsKeys.keyboardSessionActive)
        let expiryTime = defaults.double(forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
        let currentTime = Date().timeIntervalSince1970

        if isActive && currentTime > expiryTime {
            let isCurrentlyRecording = defaults.bool(forKey: UserDefaultsKeys.isRecording)
            if isCurrentlyRecording {
                return true
            }
            deactivateKeyboardSession()
            return false
        }

        return isActive
    }

    func deactivateKeyboardSession() {
        let wasActive = sharedDefaults?.bool(forKey: UserDefaultsKeys.keyboardSessionActive) ?? true
        guard wasActive else { return }

        sharedDefaults?.set(false, forKey: UserDefaultsKeys.keyboardSessionActive)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
        postDarwinNotification(NotificationNames.keyboardSessionExpired)
        logger.logError("🔑 Keyboard session deactivated")
    }

    func refreshKeyboardSessionExpiry(timeoutSeconds: Int) {
        guard let defaults = sharedDefaults else { return }
        let isActive = defaults.bool(forKey: UserDefaultsKeys.keyboardSessionActive)
        guard isActive else { return }
        let newExpiryTime = Date().timeIntervalSince1970 + Double(timeoutSeconds)
        defaults.set(newExpiryTime, forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
        defaults.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        logger.logError("🔁 Keyboard session expiry refreshed for \(timeoutSeconds) seconds")
    }

    // MARK: - Keyboard Clipboard Context

    /// Stores clipboard text captured by the keyboard extension for AI context.
    func setKeyboardClipboardContext(_ text: String?) {
        if let text {
            sharedDefaults?.set(text, forKey: UserDefaultsKeys.keyboardClipboardContext)
        } else {
            sharedDefaults?.removeObject(forKey: UserDefaultsKeys.keyboardClipboardContext)
        }
    }

    /// Retrieves and clears the keyboard-captured clipboard context.
    func getAndConsumeKeyboardClipboardContext() -> String? {
        guard let defaults = sharedDefaults else { return nil }
        let text = defaults.string(forKey: UserDefaultsKeys.keyboardClipboardContext)
        if text != nil {
            defaults.removeObject(forKey: UserDefaultsKeys.keyboardClipboardContext)
        }
        return text
    }

    // MARK: - Transcribed Text Sharing

    /// Shares transcribed text with extensions and updates status to completed.
    ///
    /// - Parameter text: The transcribed (and optionally enhanced) text.
    func shareTranscribedText(_ text: String) {
        sharedDefaults?.set(text, forKey: UserDefaultsKeys.transcribedText)
        updateTranscriptionStatus(.completed)
        postDarwinNotification(NotificationNames.transcriptionCompleted)
        logger.logError("📝 Shared transcribed text: \(text.prefix(50))...")
    }

    /// Retrieves and clears the shared transcribed text.
    ///
    /// - Returns: The transcribed text, or `nil` if none is available.
    func getAndConsumeTranscribedText() -> String? {
        guard let defaults = sharedDefaults else { return nil }

        let text = defaults.string(forKey: UserDefaultsKeys.transcribedText)
        if text != nil {
            defaults.removeObject(forKey: UserDefaultsKeys.transcribedText)
            updateTranscriptionStatus(.idle)
        }

        return text
    }

    func updateTranscriptionStatus(_ status: TranscriptionStatus) {
        sharedDefaults?.set(status.rawValue, forKey: UserDefaultsKeys.transcriptionStatus)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastRecordingTimestamp)

        logger.logError("📊 Transcription status: \(status.rawValue)")

        switch status {
        case .transcribing:
            postDarwinNotification(NotificationNames.transcriptionTranscribing)
        case .enhancing:
            postDarwinNotification(NotificationNames.transcriptionEnhancing)
        case .error:
            postDarwinNotification(NotificationNames.transcriptionError)
        case .completed:
            break
        case .idle:
            postDarwinNotification(NotificationNames.transcriptionCancelled)
        case .recording:
            break
        }
    }

    /// Convenience to set an error message and notify listeners of an error state.
    func updateTranscriptionError(_ message: String) {
        sharedDefaults?.set(message, forKey: UserDefaultsKeys.transcriptionErrorMessage)
        updateTranscriptionStatus(.error)
    }

    var transcriptionStatus: TranscriptionStatus {
        guard let defaults = sharedDefaults,
              let statusString = defaults.string(forKey: UserDefaultsKeys.transcriptionStatus),
              let status = TranscriptionStatus(rawValue: statusString) else {
            return .idle
        }
        return status
    }

    func getAndConsumeTranscriptionErrorMessage() -> String? {
        guard let defaults = sharedDefaults else { return nil }
        let message = defaults.string(forKey: UserDefaultsKeys.transcriptionErrorMessage)
        if message != nil {
            defaults.removeObject(forKey: UserDefaultsKeys.transcriptionErrorMessage)
        }
        return message
    }

    // MARK: - VivaMode Management

    public func setSelectedVivaMode(_ modeName: String) {
        sharedDefaults?.set(modeName, forKey: AppGroupCoordinator.selectedVivaModeKey)
        sharedDefaults?.synchronize()
        postDarwinNotification(NotificationNames.vivaModeChanged)
        logger.logInfo("📱 Keyboard Extension set selected VivaMode: \(modeName)")
    }

    // MARK: - Smart Formatting Setting

    /// Whether to apply smart formatting (spacing, capitalization) when pasting transcription
    /// Defaults to true if not set
    public var isSmartFormattingOnPasteEnabled: Bool {
        get {
            // Return true by default if the key doesn't exist
            if sharedDefaults?.object(forKey: AppGroupCoordinator.kSmartFormattingOnPaste) == nil {
                return true
            }
            return sharedDefaults?.bool(forKey: AppGroupCoordinator.kSmartFormattingOnPaste) ?? true
        }
        set {
            sharedDefaults?.set(newValue, forKey: AppGroupCoordinator.kSmartFormattingOnPaste)
            sharedDefaults?.synchronize()
        }
    }

    /// Whether to copy transcription to clipboard after inserting
    /// Defaults to false if not set
    public var isKeepTranscriptInClipboardEnabled: Bool {
        get {
            return sharedDefaults?.bool(forKey: AppGroupCoordinator.kKeepTranscriptInClipboard) ?? false
        }
        set {
            sharedDefaults?.set(newValue, forKey: AppGroupCoordinator.kKeepTranscriptInClipboard)
            sharedDefaults?.synchronize()
        }
    }

    /// Whether haptic feedback is enabled for keyboard key presses
    /// Defaults to true if not set
    public var isKeyboardHapticFeedbackEnabled: Bool {
        get {
            if sharedDefaults?.object(forKey: AppGroupCoordinator.kIsKeyboardHapticFeedbackEnabled) == nil {
                return true
            }
            return sharedDefaults?.bool(forKey: AppGroupCoordinator.kIsKeyboardHapticFeedbackEnabled) ?? true
        }
        set {
            sharedDefaults?.set(newValue, forKey: AppGroupCoordinator.kIsKeyboardHapticFeedbackEnabled)
            sharedDefaults?.synchronize()
        }
    }
    
    /// Whether sound feedback is enabled for keyboard key presses
    /// Defaults to true if not set
    public var isKeyboardSoundFeedbackEnabled: Bool {
        get {
            if sharedDefaults?.object(forKey: AppGroupCoordinator.kIsKeyboardSoundFeedbackEnabled) == nil {
                return true
            }
            return sharedDefaults?.bool(forKey: AppGroupCoordinator.kIsKeyboardSoundFeedbackEnabled) ?? true
        }
        set {
            sharedDefaults?.set(newValue, forKey: AppGroupCoordinator.kIsKeyboardSoundFeedbackEnabled)
            sharedDefaults?.synchronize()
        }
    }

    // MARK: - Share Extension Audio Handling

    /// Returns the shared container URL for storing audio files shared between app and extensions
    public var sharedAudioDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let audioDir = containerURL.appendingPathComponent("SharedAudio")

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioDir.path) {
            try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }

        return audioDir
    }

    /// Saves the filename of a shared audio file pending transcription
    public func setPendingSharedAudioFileName(_ fileName: String) {
        sharedDefaults?.set(fileName, forKey: AppGroupCoordinator.kPendingSharedAudioFileName)
        sharedDefaults?.synchronize()
        logger.logInfo("📁 Saved pending shared audio file: \(fileName)")
    }

    /// Retrieves and clears the pending shared audio filename
    public func getAndConsumePendingSharedAudioFileName() -> String? {
        guard let fileName = sharedDefaults?.string(forKey: AppGroupCoordinator.kPendingSharedAudioFileName) else {
            return nil
        }
        sharedDefaults?.removeObject(forKey: AppGroupCoordinator.kPendingSharedAudioFileName)
        sharedDefaults?.synchronize()
        logger.logInfo("📁 Consumed pending shared audio file: \(fileName)")
        return fileName
    }

    /// Checks if there's a pending shared audio file
    public var hasPendingSharedAudio: Bool {
        sharedDefaults?.string(forKey: AppGroupCoordinator.kPendingSharedAudioFileName) != nil
    }

    /// Saves a language override for the pending shared audio transcription
    public func setPendingLanguageOverride(_ language: String?) {
        if let language = language {
            sharedDefaults?.set(language, forKey: AppGroupCoordinator.kPendingLanguageOverride)
        } else {
            sharedDefaults?.removeObject(forKey: AppGroupCoordinator.kPendingLanguageOverride)
        }
        sharedDefaults?.synchronize()
        logger.logInfo("📁 Saved pending language override: \(language ?? "nil")")
    }

    /// Retrieves and clears the pending language override
    public func getAndConsumePendingLanguageOverride() -> String? {
        guard let language = sharedDefaults?.string(forKey: AppGroupCoordinator.kPendingLanguageOverride) else {
            return nil
        }
        sharedDefaults?.removeObject(forKey: AppGroupCoordinator.kPendingLanguageOverride)
        sharedDefaults?.synchronize()
        logger.logInfo("📁 Consumed pending language override: \(language)")
        return language
    }

    // MARK: - Darwin Notifications (Real-time Communication)

    nonisolated private func setupNotificationObservers() {
        guard let center = notificationCenter else { return }

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleStartRecordingNotification()
            },
            NotificationNames.startRecording as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleStopRecordingNotification()
            },
            NotificationNames.stopRecording as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleCancelRecordingNotification()
            },
            NotificationNames.cancelRecording as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handlePauseRecordingNotification()
            },
            NotificationNames.pauseRecording as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleResumeRecordingNotification()
            },
            NotificationNames.resumeRecording as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleTranscriptionTranscribingNotification()
            },
            NotificationNames.transcriptionTranscribing as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleTranscriptionEnhancingNotification()
            },
            NotificationNames.transcriptionEnhancing as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleTranscriptionCompletedNotification()
            },
            NotificationNames.transcriptionCompleted as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleTranscriptionErrorNotification()
            },
            NotificationNames.transcriptionError as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleTranscriptionCancelledNotification()
            },
            NotificationNames.transcriptionCancelled as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleAudioLevelUpdatedNotification()
            },
            NotificationNames.audioLevelUpdated as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleRecordingStateChangedNotification()
            },
            NotificationNames.recordingStateChanged as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleKeyboardSessionActivatedNotification()
            },
            NotificationNames.keyboardSessionActivated as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleKeyboardSessionExpiredNotification()
            },
            NotificationNames.keyboardSessionExpired as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleStartRecordingFromControlNotification()
            },
            NotificationNames.startRecordingFromControl as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleTerminateSessionFromLiveActivityNotification()
            },
            NotificationNames.terminateSessionFromLiveActivity as CFString,
            nil,
            .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleVivaModeChangedNotification()
            },
            NotificationNames.vivaModeChanged as CFString,
            nil,
            .deliverImmediately
        )
    }

    nonisolated private func removeNotificationObservers() {
        guard let center = notificationCenter else { return }
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    nonisolated private func postDarwinNotification(_ name: String) {
        guard let center = notificationCenter else { return }
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    // MARK: - Notification Handlers

    nonisolated private func handleStartRecordingNotification() {
        Task { @MainActor in
            await onStartRecordingRequested?()
        }
    }

    nonisolated private func handleStopRecordingNotification() {
        Task { @MainActor in
            await onStopRecordingRequested?()
        }
    }

    nonisolated private func handleCancelRecordingNotification() {
        Task { @MainActor in
            await onCancelRecordingRequested?()
        }
    }

    nonisolated private func handlePauseRecordingNotification() {
        Task { @MainActor in
            await onPauseRecordingRequested?()
        }
    }

    nonisolated private func handleResumeRecordingNotification() {
        Task { @MainActor in
            await onResumeRecordingRequested?()
        }
    }

    nonisolated private func handleTranscriptionTranscribingNotification() {
        Task { @MainActor in
            await onTranscriptionTranscribing?()
        }
    }

    nonisolated private func handleTranscriptionEnhancingNotification() {
        Task { @MainActor in
            await onTranscriptionEnhancing?()
        }
    }

    nonisolated private func handleTranscriptionCompletedNotification() {
        Task { @MainActor in
            let text = await getAndConsumeTranscribedText() ?? ""
            await onTranscriptionCompleted?(text)
        }
    }

    nonisolated private func handleTranscriptionErrorNotification() {
        Task { @MainActor in
            let message = await getAndConsumeTranscriptionErrorMessage() ?? ""
            await onTranscriptionError?()
            if !message.isEmpty {
                await onTranscriptionErrorMessage?(message)
            }
        }
    }

    nonisolated private func handleTranscriptionCancelledNotification() {
        Task { @MainActor in
            await onTranscriptionCancelled?()
        }
    }

    nonisolated private func handleAudioLevelUpdatedNotification() {
        Task { @MainActor in
            let level = await currentAudioLevel
            await onAudioLevelUpdated?(level)
        }
    }

    nonisolated private func handleRecordingStateChangedNotification() {
        Task { @MainActor in
            let recording = await isRecording
            await onRecordingStateChanged?(recording)
        }
    }

    nonisolated private func handleKeyboardSessionActivatedNotification() {
        Task { @MainActor in
            await onKeyboardSessionActivated?()
        }
    }

    nonisolated private func handleKeyboardSessionExpiredNotification() {
        Task { @MainActor in
            await onKeyboardSessionExpired?()
        }
    }

    nonisolated private func handleStartRecordingFromControlNotification() {
        Task { @MainActor in
            await onStartRecordingFromControl?()
        }
    }

    nonisolated private func handleTerminateSessionFromLiveActivityNotification() {
        Task { @MainActor in
            await onTerminateSessionFromLiveActivity?()
        }
    }

    nonisolated private func handleVivaModeChangedNotification() {
        Task { @MainActor in
            await onVivaModeChanged?()
        }
    }
}

