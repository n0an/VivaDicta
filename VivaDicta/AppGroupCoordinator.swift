//
//  AppGroupCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.03
//



@preconcurrency import Foundation
import os


/// Handles communication between the main app and the keyboard extension
/// Uses App Groups + Darwin Notifications for reliable iOS-native communication
public final class AppGroupCoordinator {
    public static let shared = AppGroupCoordinator()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AppGroupCoordinator")

    
    // MARK: - Constants
    public let appGroupId = "group.com.antonnovoselov.VivaDicta"
    // AI Enhancement configuration
    public static let aiEnhanceModesKey = "AIEnhanceModes"
    public static let selectedAIModeKey = "selectedAIMode"
    
    
    nonisolated private enum UserDefaultsKeys {
        static let shouldStartRecording = "shouldStartRecording"
        static let shouldStopRecording = "shouldStopRecording"
        static let shouldCancelRecording = "shouldCancelRecording"
        static let shouldPauseRecording = "shouldPauseRecording"
        static let shouldResumeRecording = "shouldResumeRecording"
        static let isRecording = "isRecording"
        static let isPaused = "isPaused"
        static let lastRecordingTimestamp = "lastRecordingTimestamp"
        static let transcribedText = "transcribedText"
        static let transcriptionStatus = "transcriptionStatus"
        static let keyboardSessionActive = "keyboardSessionActive"
        static let keyboardSessionExpiryTime = "keyboardSessionExpiryTime"
        static let audioLevel = "audioLevel" // 0.0 ... 1.0
        static let transcriptionErrorMessage = "transcriptionErrorMessage"
    }

    nonisolated private enum NotificationNames {
        static let startRecording = "com.antonnovoselov.VivaDicta.startRecording"
        static let stopRecording = "com.antonnovoselov.VivaDicta.stopRecording"
        static let cancelRecording = "com.antonnovoselov.VivaDicta.cancelRecording"
        static let pauseRecording = "com.antonnovoselov.VivaDicta.pauseRecording"
        static let resumeRecording = "com.antonnovoselov.VivaDicta.resumeRecording"
        static let recordingStateChanged = "com.antonnovoselov.VivaDicta.recordingStateChanged"
        static let pausedStateChanged = "com.antonnovoselov.VivaDicta.pausedStateChanged"
        static let transcriptionCompleted = "com.antonnovoselov.VivaDicta.transcriptionCompleted"
        static let keyboardSessionActivated = "com.antonnovoselov.VivaDicta.keyboardSessionActivated"
        static let keyboardSessionExpired = "com.antonnovoselov.VivaDicta.keyboardSessionExpired"
        static let transcriptionTranscribing = "com.antonnovoselov.VivaDicta.transcriptionTranscribing"
        static let transcriptionEnhancing = "com.antonnovoselov.VivaDicta.transcriptionEnhancing"
        static let transcriptionError = "com.antonnovoselov.VivaDicta.transcriptionError"
        static let audioLevelUpdated = "com.antonnovoselov.VivaDicta.audioLevelUpdated"
        static let stopHotMicFromWidget = "com.antonnovoselov.VivaDicta.stopHotMicFromWidget"
    }

    public enum TranscriptionStatus: String {
        case idle = "idle"
        case recording = "recording"
        case transcribing = "transcribing"
        case enhancing = "enhancing"
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
    @MainActor var onTranscriptionErrorMessage: ((String) -> Void)?
    @MainActor var onKeyboardSessionExpired: (() -> Void)?
    @MainActor var onAudioLevelUpdated: ((CGFloat) -> Void)?
    @MainActor var onRecordingStateChanged: ((Bool) -> Void)?
    @MainActor var onPausedStateChanged: ((Bool) -> Void)?
    @MainActor var onStopHotMicFromWidget: (() -> Void)?

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

        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.shouldStartRecording)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.shouldStopRecording)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.shouldCancelRecording)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.shouldPauseRecording)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.shouldResumeRecording)

        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.isPaused)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.audioLevel)
        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.transcriptionErrorMessage)

        sharedDefaults?.removeObject(forKey: UserDefaultsKeys.lastRecordingTimestamp)

        logger.logError("🧹 Complete session state reset on app launch - fresh start")
    }

    // MARK: - Public Interface for Keyboard Extension

    public func requestStartRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldStartRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.startRecording)
    }

    public func requestStopRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldStopRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.stopRecording)
    }

    public func requestCancelRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldCancelRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.cancelRecording)
    }

    func requestPauseRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldPauseRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.pauseRecording)
    }

    func requestResumeRecording() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldResumeRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.resumeRecording)
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

    func updatePausedState(_ isPaused: Bool) {
        sharedDefaults?.set(isPaused, forKey: UserDefaultsKeys.isPaused)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        postDarwinNotification(NotificationNames.pausedStateChanged)
        logger.logError("📡 Updated paused state: \(isPaused)")
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

    func checkAndConsumeStartRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }

        let shouldStart = defaults.bool(forKey: UserDefaultsKeys.shouldStartRecording)
        if shouldStart {
            defaults.set(false, forKey: UserDefaultsKeys.shouldStartRecording)
            return true
        }
        return false
    }

    func checkAndConsumeStopRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }

        let shouldStop = defaults.bool(forKey: UserDefaultsKeys.shouldStopRecording)
        if shouldStop {
            defaults.set(false, forKey: UserDefaultsKeys.shouldStopRecording)
            return true
        }
        return false
    }

    func checkAndConsumeCancelRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }

        let shouldCancel = defaults.bool(forKey: UserDefaultsKeys.shouldCancelRecording)
        if shouldCancel {
            defaults.set(false, forKey: UserDefaultsKeys.shouldCancelRecording)
            return true
        }
        return false
    }

    func checkAndConsumePauseRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }

        let shouldPause = defaults.bool(forKey: UserDefaultsKeys.shouldPauseRecording)
        if shouldPause {
            defaults.set(false, forKey: UserDefaultsKeys.shouldPauseRecording)
            return true
        }
        return false
    }

    func checkAndConsumeResumeRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }

        let shouldResume = defaults.bool(forKey: UserDefaultsKeys.shouldResumeRecording)
        if shouldResume {
            defaults.set(false, forKey: UserDefaultsKeys.shouldResumeRecording)
            return true
        }
        return false
    }

    // MARK: - Keyboard Dictation Session Management

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

    var isPaused: Bool {
        let stored = sharedDefaults?.bool(forKey: UserDefaultsKeys.isPaused) ?? false
        return stored
    }

    var keyboardSessionRemainingSeconds: TimeInterval {
        guard let defaults = sharedDefaults else { return 0 }

        let expiryTime = defaults.double(forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
        let currentTime = Date().timeIntervalSince1970

        return max(0, expiryTime - currentTime)
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

    // MARK: - Transcribed Text Sharing

    func shareTranscribedText(_ text: String) {
        sharedDefaults?.set(text, forKey: UserDefaultsKeys.transcribedText)
        updateTranscriptionStatus(.completed)
        postDarwinNotification(NotificationNames.transcriptionCompleted)
        logger.logError("📝 Shared transcribed text: \(text.prefix(50))...")
    }

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
        case .idle, .recording:
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
                coordinator.handlePausedStateChangedNotification()
            },
            NotificationNames.pausedStateChanged as CFString,
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
                coordinator.handleStopHotMicFromWidgetNotification()
            },
            NotificationNames.stopHotMicFromWidget as CFString,
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

    nonisolated private func handlePausedStateChangedNotification() {
        Task { @MainActor in
            let paused = await isPaused
            await onPausedStateChanged?(paused)
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

    nonisolated private func handleStopHotMicFromWidgetNotification() {
        // Trust the notification and stop immediately
        Task { @MainActor in
            await onStopHotMicFromWidget?()
        }
    }

    // MARK: - Debug Helpers

    /// Clear all shared data (useful for debugging)
    func clearAllSharedData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: UserDefaultsKeys.shouldStartRecording)
        defaults.removeObject(forKey: UserDefaultsKeys.shouldStopRecording)
        defaults.removeObject(forKey: UserDefaultsKeys.isRecording)
        defaults.removeObject(forKey: UserDefaultsKeys.lastRecordingTimestamp)
        defaults.removeObject(forKey: UserDefaultsKeys.transcribedText)
        defaults.removeObject(forKey: UserDefaultsKeys.transcriptionStatus)
        defaults.removeObject(forKey: UserDefaultsKeys.keyboardSessionActive)
        defaults.removeObject(forKey: UserDefaultsKeys.keyboardSessionExpiryTime)
    }

    func getDebugInfo() -> [String: Any] {
        guard let defaults = sharedDefaults else { return ["error": "No shared defaults"] }

        return [
            "shouldStartRecording": defaults.bool(forKey: UserDefaultsKeys.shouldStartRecording),
            "shouldStopRecording": defaults.bool(forKey: UserDefaultsKeys.shouldStopRecording),
            "isRecording": defaults.bool(forKey: UserDefaultsKeys.isRecording),
            "lastRecordingTimestamp": defaults.double(forKey: UserDefaultsKeys.lastRecordingTimestamp),
            "transcribedText": defaults.string(forKey: UserDefaultsKeys.transcribedText) ?? "",
            "transcriptionStatus": defaults.string(forKey: UserDefaultsKeys.transcriptionStatus) ?? "idle",
            "keyboardSessionActive": defaults.bool(forKey: UserDefaultsKeys.keyboardSessionActive),
            "keyboardSessionExpiryTime": defaults.double(forKey: UserDefaultsKeys.keyboardSessionExpiryTime),
            "keyboardSessionRemainingSeconds": keyboardSessionRemainingSeconds,

            // Add stop hot mic debug info
            "stopHotMicRequested": defaults.bool(forKey: "stopHotMicRequested"),
            "stopHotMicRequestedTimestamp": defaults.double(forKey: "stopHotMicRequestedTimestamp"),

            "appGroupIdentifier": appGroupId
        ]
    }
}






















// MARK: - App Groups Configuration
//public enum AppGroupConfig {
//    // App Group ID
//    public static let appGroupId = "group.com.antonnovoselov.VivaDicta"
//
//    // Heartbeat configuration
//    public static let heartbeatKey = "appLastHeartbeat"
//    public static let isMainAppActiveKey = "isMainAppActive"
//    public static let heartbeatInterval: TimeInterval = 5.0
//    public static let heartbeatThreshold: TimeInterval = 10.0  // Consider app active if heartbeat is within 10 seconds
//
//    // Recording heartbeat configuration
//    public static let recordingHeartbeatKey = "recordingLastHeartbeat"
//    public static let recordingHeartbeatInterval: TimeInterval = 5.0
//    public static let recordingHeartbeatThreshold: TimeInterval = 10.0  // Consider recording active if heartbeat is within 10 seconds
//
//    // Timeout configuration
//    public static let recordingStartTimeout: TimeInterval = 10.0  // Keyboard: timeout for recording to start
//    public static let audioPrewarmSessionTimeout: TimeInterval = 300.0  // Audio prewarm session timeout (5 minutes)
////    public static let keyboardDictationTimeoutSeconds: Int = 180 // 3 minutes hot mic session
//
//    // AI Enhancement configuration
//    public static let aiEnhanceModesKey = "AIEnhanceModes"
//    public static let selectedAIModeKey = "selectedAIMode"
//}
//
//// MARK: - Darwin Notification Names
//public enum DarwinNotificationName {
//    /// Notification sent from keyboard to start recording
//    nonisolated(unsafe) public static let startRecording = "com.antonnovoselov.VivaDicta.startRecording"
//
//    /// Notification sent from keyboard to stop recording
//    nonisolated(unsafe) public static let stopRecording = "com.antonnovoselov.VivaDicta.stopRecording"
//
//    /// Notification sent from keyboard to cancel recording without transcription
//    nonisolated(unsafe) public static let cancelRecording = "com.antonnovoselov.VivaDicta.cancelRecording"
//
//    /// Notification sent from main app when transcription is ready
//    nonisolated(unsafe) public static let transcriptionReady = "com.antonnovoselov.VivaDicta.transcriptionReady"
//
//    /// Notification sent from main app when recording has started
//    nonisolated(unsafe) public static let recordingStarted = "com.antonnovoselov.VivaDicta.recordingStarted"
//
//    /// Notification sent from main app when recording has stopped
//    nonisolated(unsafe) public static let recordingStopped = "com.antonnovoselov.VivaDicta.recordingStopped"
//
//    /// Notification sent when an error occurs
//    nonisolated(unsafe) public static let recordingError = "com.antonnovoselov.VivaDicta.recordingError"
//
//    /// Notification sent when transcription starts
//    nonisolated(unsafe) public static let transcriptionStarted = "com.antonnovoselov.VivaDicta.transcriptionStarted"
//
//    /// Notification sent when transcription ends
//    nonisolated(unsafe) public static let transcriptionEnded = "com.antonnovoselov.VivaDicta.transcriptionEnded"
//
//    /// Notification sent when AI enhancement starts
//    nonisolated(unsafe) public static let aiEnhancementStarted = "com.antonnovoselov.VivaDicta.aiEnhancementStarted"
//
//    /// Notification sent when AI enhancement ends
//    nonisolated(unsafe) public static let aiEnhancementEnded = "com.antonnovoselov.VivaDicta.aiEnhancementEnded"
//}
//
//// MARK: - Darwin Notification Center
//public actor AppGroupCoordinator {
//
//    // MARK: - Properties
//    public static let shared = AppGroupCoordinator()
//    private nonisolated(unsafe) let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
//    private let observationsLock = NSLock()
//    private nonisolated(unsafe) var observations: [String: Unmanaged<DarwinNotificationCallback>] = [:]  // Protected by observationsLock
//    
//    var onStopHotMicFromWidget: (() -> Void)?
//
//    // MARK: - Initialization
//    private init() {}
//
//    // Note: No deinit needed since this is a singleton that lives for the app's lifetime
//    // The OS will clean up Darwin notification observers when the app terminates
//
//    // MARK: - Posting Notifications
//
//    /// Post a Darwin notification to communicate between app and keyboard extension
//    nonisolated public func postNotification(_ name: String) {
//        CFNotificationCenterPostNotification(
//            darwinCenter,
//            CFNotificationName(rawValue: name as CFString),
//            nil,
//            nil,
//            true
//        )
//    }
//
//    /// Request to start recording (sent from keyboard)
//    nonisolated public func requestStartRecording() {
//        postNotification(DarwinNotificationName.startRecording)
//    }
//
//    /// Request to stop recording (sent from keyboard)
//    nonisolated public func requestStopRecording() {
//        postNotification(DarwinNotificationName.stopRecording)
//    }
//
//    /// Request to cancel recording without transcription (sent from keyboard)
//    nonisolated public func requestCancelRecording() {
//        postNotification(DarwinNotificationName.cancelRecording)
//    }
//
//    /// Notify that transcription is ready (sent from main app)
//    nonisolated public func notifyTranscriptionReady() {
//        postNotification(DarwinNotificationName.transcriptionReady)
//    }
//
//    /// Notify that recording has started (sent from main app)
//    nonisolated public func notifyRecordingStarted() {
//        postNotification(DarwinNotificationName.recordingStarted)
//    }
//
//    /// Notify that recording has stopped (sent from main app)
//    nonisolated public func notifyRecordingStopped() {
//        postNotification(DarwinNotificationName.recordingStopped)
//    }
//
//    /// Notify that an error occurred (sent from main app)
//    nonisolated public func notifyRecordingError() {
//        postNotification(DarwinNotificationName.recordingError)
//    }
//
//    /// Notify that transcription has started (sent from main app)
//    nonisolated public func notifyTranscriptionStarted() {
//        postNotification(DarwinNotificationName.transcriptionStarted)
//    }
//
//    /// Notify that transcription has ended (sent from main app)
//    nonisolated public func notifyTranscriptionEnded() {
//        postNotification(DarwinNotificationName.transcriptionEnded)
//    }
//
//    /// Notify that AI enhancement has started (sent from main app)
//    nonisolated public func notifyAIEnhancementStarted() {
//        postNotification(DarwinNotificationName.aiEnhancementStarted)
//    }
//
//    /// Notify that AI enhancement has ended (sent from main app)
//    nonisolated public func notifyAIEnhancementEnded() {
//        postNotification(DarwinNotificationName.aiEnhancementEnded)
//    }
//
//    // MARK: - Observing Notifications
//
//    /// Add observer for a Darwin notification
//    /// - Parameters:
//    ///   - name: The notification name to observe
//    ///   - callback: The callback to execute when notification is received
//    nonisolated public func addObserver(for name: String, callback: @escaping @Sendable () -> Void) {
//        observationsLock.lock()
//        defer { observationsLock.unlock() }
//
//        // Remove existing observer if any
//        if let existingObserver = observations[name] {
//            CFNotificationCenterRemoveObserver(
//                darwinCenter,
//                existingObserver.toOpaque(),
//                CFNotificationName(rawValue: name as CFString),
//                nil
//            )
//            existingObserver.release()  // Release the retained callback
//        }
//
//        // Create a context object to hold the callback
//        let callbackObject = DarwinNotificationCallback(callback: callback)
//        let observer = Unmanaged.passRetained(callbackObject)
//
//        CFNotificationCenterAddObserver(
//            darwinCenter,
//            observer.toOpaque(),
//            { _, observer, name, _, _ in
//                if let observer = observer {
//                    let callback = Unmanaged<DarwinNotificationCallback>.fromOpaque(observer).takeUnretainedValue()
//                    callback.invoke()
//                }
//            },
//            name as CFString,
//            nil,
//            .deliverImmediately
//        )
//
//        // Keep reference to manage memory properly
//        observations[name] = observer
//    }
//
//    /// Remove observer for a Darwin notification
//    nonisolated public func removeObserver(for name: String) {
//        observationsLock.lock()
//        defer { observationsLock.unlock() }
//
//        // Remove from notification center
//        if let observer = observations[name] {
//            CFNotificationCenterRemoveObserver(
//                darwinCenter,
//                observer.toOpaque(),
//                CFNotificationName(rawValue: name as CFString),
//                nil
//            )
//            observer.release()  // Release the retained callback
//            observations.removeValue(forKey: name)
//        }
//    }
//
//    /// Remove all observers
//    nonisolated public func removeAllObservers() {
//        observationsLock.lock()
//        defer { observationsLock.unlock() }
//
//        // Release all retained callbacks and remove observers
//        for (name, observer) in observations {
//            CFNotificationCenterRemoveObserver(
//                darwinCenter,
//                observer.toOpaque(),
//                CFNotificationName(rawValue: name as CFString),
//                nil
//            )
//            observer.release()  // Release the retained callback
//        }
//        observations.removeAll()
//    }
//
//    // MARK: - Convenience Methods for Observing
//    
//    private func handleStopHotMicFromWidgetNotification() {
//        // Trust the notification and stop immediately
//        DispatchQueue.main.async { [weak self] in
//            self?.onStopHotMicFromWidget?()
//        }
//    }
//    
//    
//    
//    
//    
//    
//
//    /// Observe start recording requests
//    nonisolated public func observeStartRecording(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.startRecording, callback: callback)
//    }
//
//    /// Observe stop recording requests
//    nonisolated public func observeStopRecording(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.stopRecording, callback: callback)
//    }
//
//    /// Observe cancel recording requests
//    nonisolated public func observeCancelRecording(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.cancelRecording, callback: callback)
//    }
//
//    /// Observe transcription ready notifications
//    nonisolated public func observeTranscriptionReady(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.transcriptionReady, callback: callback)
//    }
//
//    /// Observe recording started notifications
//    nonisolated public func observeRecordingStarted(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.recordingStarted, callback: callback)
//    }
//
//    /// Observe recording stopped notifications
//    nonisolated public func observeRecordingStopped(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.recordingStopped, callback: callback)
//    }
//
//    /// Observe recording error notifications
//    nonisolated public func observeRecordingError(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.recordingError, callback: callback)
//    }
//
//    /// Observe transcription started notifications
//    nonisolated public func observeTranscriptionStarted(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.transcriptionStarted, callback: callback)
//    }
//
//    /// Observe transcription ended notifications
//    nonisolated public func observeTranscriptionEnded(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.transcriptionEnded, callback: callback)
//    }
//
//    /// Observe AI enhancement started notifications
//    nonisolated public func observeAIEnhancementStarted(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.aiEnhancementStarted, callback: callback)
//    }
//
//    /// Observe AI enhancement ended notifications
//    nonisolated public func observeAIEnhancementEnded(callback: @escaping @Sendable () -> Void) {
//        addObserver(for: DarwinNotificationName.aiEnhancementEnded, callback: callback)
//    }
//
//    // MARK: - Convenience Methods for Cleanup
//
//    /// Remove all keyboard-specific observers (used by keyboard extension)
//    nonisolated public func removeKeyboardObservers() {
//        removeObserver(for: DarwinNotificationName.recordingStarted)
//        removeObserver(for: DarwinNotificationName.recordingStopped)
//        removeObserver(for: DarwinNotificationName.transcriptionReady)
//        removeObserver(for: DarwinNotificationName.recordingError)
//        removeObserver(for: DarwinNotificationName.transcriptionStarted)
//        removeObserver(for: DarwinNotificationName.transcriptionEnded)
//        removeObserver(for: DarwinNotificationName.aiEnhancementStarted)
//        removeObserver(for: DarwinNotificationName.aiEnhancementEnded)
//    }
//
//    /// Remove all main app recording observers (used by main app)
//    nonisolated public func removeMainAppObservers() {
//        removeObserver(for: DarwinNotificationName.startRecording)
//        removeObserver(for: DarwinNotificationName.stopRecording)
//        removeObserver(for: DarwinNotificationName.cancelRecording)
//    }
//}
//
//// MARK: - Helper Class for Callbacks
//private final class DarwinNotificationCallback: @unchecked Sendable {
//    let callback: @Sendable () -> Void
//
//    nonisolated init(callback: @escaping @Sendable () -> Void) {
//        self.callback = callback
//    }
//
//    nonisolated func invoke() {
//        callback()
//    }
//}
