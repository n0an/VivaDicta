//
//  AppGroupCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

// MARK: - App Groups Configuration
public enum AppGroupConfig {
    static let appGroupId = "group.com.antonnovoselov.VivaDicta"
    static let heartbeatKey = "appLastHeartbeat"
    static let isMainAppActiveKey = "isMainAppActive"
    static let heartbeatInterval: TimeInterval = 5.0
    static let heartbeatThreshold: TimeInterval = 10.0  // Consider app active if heartbeat is within 10 seconds

    // Recording heartbeat configuration
    static let recordingHeartbeatKey = "recordingLastHeartbeat"
    static let recordingHeartbeatInterval: TimeInterval = 5.0
    static let recordingHeartbeatThreshold: TimeInterval = 10.0  // Consider recording active if heartbeat is within 10 seconds
}

// MARK: - Darwin Notification Names
public enum DarwinNotificationName {
    /// Notification sent from keyboard to start recording
    nonisolated(unsafe) public static let startRecording = "com.antonnovoselov.VivaDicta.startRecording"

    /// Notification sent from keyboard to stop recording
    nonisolated(unsafe) public static let stopRecording = "com.antonnovoselov.VivaDicta.stopRecording"

    /// Notification sent from keyboard to cancel recording without transcription
    nonisolated(unsafe) public static let cancelRecording = "com.antonnovoselov.VivaDicta.cancelRecording"

    /// Notification sent from main app when transcription is ready
    nonisolated(unsafe) public static let transcriptionReady = "com.antonnovoselov.VivaDicta.transcriptionReady"

    /// Notification sent from main app when recording has started
    nonisolated(unsafe) public static let recordingStarted = "com.antonnovoselov.VivaDicta.recordingStarted"

    /// Notification sent from main app when recording has stopped
    nonisolated(unsafe) public static let recordingStopped = "com.antonnovoselov.VivaDicta.recordingStopped"

    /// Notification sent when an error occurs
    nonisolated(unsafe) public static let recordingError = "com.antonnovoselov.VivaDicta.recordingError"

    /// Notification sent when transcription starts
    nonisolated(unsafe) public static let transcriptionStarted = "com.antonnovoselov.VivaDicta.transcriptionStarted"

    /// Notification sent when transcription ends
    nonisolated(unsafe) public static let transcriptionEnded = "com.antonnovoselov.VivaDicta.transcriptionEnded"

    /// Notification sent when AI enhancement starts
    nonisolated(unsafe) public static let aiEnhancementStarted = "com.antonnovoselov.VivaDicta.aiEnhancementStarted"

    /// Notification sent when AI enhancement ends
    nonisolated(unsafe) public static let aiEnhancementEnded = "com.antonnovoselov.VivaDicta.aiEnhancementEnded"
}

// MARK: - Darwin Notification Center
public actor AppGroupCoordinator {

    // MARK: - Properties
    public static let shared = AppGroupCoordinator()
    private nonisolated(unsafe) let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
    private let observationsLock = NSLock()
    private nonisolated(unsafe) var observations: [String: Unmanaged<DarwinNotificationCallback>] = [:]  // Protected by observationsLock

    // MARK: - Initialization
    private init() {}

    // Note: No deinit needed since this is a singleton that lives for the app's lifetime
    // The OS will clean up Darwin notification observers when the app terminates

    // MARK: - Posting Notifications

    /// Post a Darwin notification to communicate between app and keyboard extension
    nonisolated public func postNotification(_ name: String) {
        CFNotificationCenterPostNotification(
            darwinCenter,
            CFNotificationName(rawValue: name as CFString),
            nil,
            nil,
            true
        )
    }

    /// Request to start recording (sent from keyboard)
    nonisolated public func requestStartRecording() {
        postNotification(DarwinNotificationName.startRecording)
    }

    /// Request to stop recording (sent from keyboard)
    nonisolated public func requestStopRecording() {
        postNotification(DarwinNotificationName.stopRecording)
    }

    /// Request to cancel recording without transcription (sent from keyboard)
    nonisolated public func requestCancelRecording() {
        postNotification(DarwinNotificationName.cancelRecording)
    }

    /// Notify that transcription is ready (sent from main app)
    nonisolated public func notifyTranscriptionReady() {
        postNotification(DarwinNotificationName.transcriptionReady)
    }

    /// Notify that recording has started (sent from main app)
    nonisolated public func notifyRecordingStarted() {
        postNotification(DarwinNotificationName.recordingStarted)
    }

    /// Notify that recording has stopped (sent from main app)
    nonisolated public func notifyRecordingStopped() {
        postNotification(DarwinNotificationName.recordingStopped)
    }

    /// Notify that an error occurred (sent from main app)
    nonisolated public func notifyRecordingError() {
        postNotification(DarwinNotificationName.recordingError)
    }

    /// Notify that transcription has started (sent from main app)
    nonisolated public func notifyTranscriptionStarted() {
        postNotification(DarwinNotificationName.transcriptionStarted)
    }

    /// Notify that transcription has ended (sent from main app)
    nonisolated public func notifyTranscriptionEnded() {
        postNotification(DarwinNotificationName.transcriptionEnded)
    }

    /// Notify that AI enhancement has started (sent from main app)
    nonisolated public func notifyAIEnhancementStarted() {
        postNotification(DarwinNotificationName.aiEnhancementStarted)
    }

    /// Notify that AI enhancement has ended (sent from main app)
    nonisolated public func notifyAIEnhancementEnded() {
        postNotification(DarwinNotificationName.aiEnhancementEnded)
    }

    // MARK: - Observing Notifications

    /// Add observer for a Darwin notification
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - callback: The callback to execute when notification is received
    nonisolated public func addObserver(for name: String, callback: @escaping @Sendable () -> Void) {
        observationsLock.lock()
        defer { observationsLock.unlock() }

        // Remove existing observer if any
        if let existingObserver = observations[name] {
            CFNotificationCenterRemoveObserver(
                darwinCenter,
                existingObserver.toOpaque(),
                CFNotificationName(rawValue: name as CFString),
                nil
            )
            existingObserver.release()  // Release the retained callback
        }

        // Create a context object to hold the callback
        let callbackObject = DarwinNotificationCallback(callback: callback)
        let observer = Unmanaged.passRetained(callbackObject)

        CFNotificationCenterAddObserver(
            darwinCenter,
            observer.toOpaque(),
            { _, observer, name, _, _ in
                if let observer = observer {
                    let callback = Unmanaged<DarwinNotificationCallback>.fromOpaque(observer).takeUnretainedValue()
                    callback.invoke()
                }
            },
            name as CFString,
            nil,
            .deliverImmediately
        )

        // Keep reference to manage memory properly
        observations[name] = observer
    }

    /// Remove observer for a Darwin notification
    nonisolated public func removeObserver(for name: String) {
        observationsLock.lock()
        defer { observationsLock.unlock() }

        // Remove from notification center
        if let observer = observations[name] {
            CFNotificationCenterRemoveObserver(
                darwinCenter,
                observer.toOpaque(),
                CFNotificationName(rawValue: name as CFString),
                nil
            )
            observer.release()  // Release the retained callback
            observations.removeValue(forKey: name)
        }
    }

    /// Remove all observers
    nonisolated public func removeAllObservers() {
        observationsLock.lock()
        defer { observationsLock.unlock() }

        // Release all retained callbacks and remove observers
        for (name, observer) in observations {
            CFNotificationCenterRemoveObserver(
                darwinCenter,
                observer.toOpaque(),
                CFNotificationName(rawValue: name as CFString),
                nil
            )
            observer.release()  // Release the retained callback
        }
        observations.removeAll()
    }

    // MARK: - Convenience Methods for Observing

    /// Observe start recording requests
    nonisolated public func observeStartRecording(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.startRecording, callback: callback)
    }

    /// Observe stop recording requests
    nonisolated public func observeStopRecording(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.stopRecording, callback: callback)
    }

    /// Observe cancel recording requests
    nonisolated public func observeCancelRecording(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.cancelRecording, callback: callback)
    }

    /// Observe transcription ready notifications
    nonisolated public func observeTranscriptionReady(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.transcriptionReady, callback: callback)
    }

    /// Observe recording started notifications
    nonisolated public func observeRecordingStarted(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.recordingStarted, callback: callback)
    }

    /// Observe recording stopped notifications
    nonisolated public func observeRecordingStopped(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.recordingStopped, callback: callback)
    }

    /// Observe recording error notifications
    nonisolated public func observeRecordingError(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.recordingError, callback: callback)
    }

    /// Observe transcription started notifications
    nonisolated public func observeTranscriptionStarted(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.transcriptionStarted, callback: callback)
    }

    /// Observe transcription ended notifications
    nonisolated public func observeTranscriptionEnded(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.transcriptionEnded, callback: callback)
    }

    /// Observe AI enhancement started notifications
    nonisolated public func observeAIEnhancementStarted(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.aiEnhancementStarted, callback: callback)
    }

    /// Observe AI enhancement ended notifications
    nonisolated public func observeAIEnhancementEnded(callback: @escaping @Sendable () -> Void) {
        addObserver(for: DarwinNotificationName.aiEnhancementEnded, callback: callback)
    }

    // MARK: - Convenience Methods for Cleanup

    /// Remove all keyboard-specific observers (used by keyboard extension)
    nonisolated public func removeKeyboardObservers() {
        removeObserver(for: DarwinNotificationName.recordingStarted)
        removeObserver(for: DarwinNotificationName.recordingStopped)
        removeObserver(for: DarwinNotificationName.transcriptionReady)
        removeObserver(for: DarwinNotificationName.recordingError)
        removeObserver(for: DarwinNotificationName.transcriptionStarted)
        removeObserver(for: DarwinNotificationName.transcriptionEnded)
        removeObserver(for: DarwinNotificationName.aiEnhancementStarted)
        removeObserver(for: DarwinNotificationName.aiEnhancementEnded)
    }

    /// Remove all main app recording observers (used by main app)
    nonisolated public func removeMainAppObservers() {
        removeObserver(for: DarwinNotificationName.startRecording)
        removeObserver(for: DarwinNotificationName.stopRecording)
        removeObserver(for: DarwinNotificationName.cancelRecording)
    }
}

// MARK: - Helper Class for Callbacks
private final class DarwinNotificationCallback: @unchecked Sendable {
    let callback: @Sendable () -> Void

    nonisolated init(callback: @escaping @Sendable () -> Void) {
        self.callback = callback
    }

    nonisolated func invoke() {
        callback()
    }
}
