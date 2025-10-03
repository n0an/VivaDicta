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
    static let startRecording = "com.antonnovoselov.VivaDicta.startRecording"

    /// Notification sent from keyboard to stop recording
    static let stopRecording = "com.antonnovoselov.VivaDicta.stopRecording"

    /// Notification sent from main app when transcription is ready
    static let transcriptionReady = "com.antonnovoselov.VivaDicta.transcriptionReady"

    /// Notification sent from main app when recording has started
    static let recordingStarted = "com.antonnovoselov.VivaDicta.recordingStarted"

    /// Notification sent from main app when recording has stopped
    static let recordingStopped = "com.antonnovoselov.VivaDicta.recordingStopped"

    /// Notification sent when an error occurs
    static let recordingError = "com.antonnovoselov.VivaDicta.recordingError"
}

// MARK: - Darwin Notification Center
public final class AppGroupCoordinator: @unchecked Sendable {

    // MARK: - Properties
    public static let shared = AppGroupCoordinator()
    private let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
    private var observations: [Any] = []

    // MARK: - Initialization
    private init() {}

    // MARK: - Posting Notifications

    /// Post a Darwin notification to communicate between app and keyboard extension
    public func postNotification(_ name: String) {
        CFNotificationCenterPostNotification(
            darwinCenter,
            CFNotificationName(rawValue: name as CFString),
            nil,
            nil,
            true
        )
    }

    /// Request to start recording (sent from keyboard)
    public func requestStartRecording() {
        postNotification(DarwinNotificationName.startRecording)
    }

    /// Request to stop recording (sent from keyboard)
    public func requestStopRecording() {
        postNotification(DarwinNotificationName.stopRecording)
    }

    /// Notify that transcription is ready (sent from main app)
    public func notifyTranscriptionReady() {
        postNotification(DarwinNotificationName.transcriptionReady)
    }

    /// Notify that recording has started (sent from main app)
    public func notifyRecordingStarted() {
        postNotification(DarwinNotificationName.recordingStarted)
    }

    /// Notify that recording has stopped (sent from main app)
    public func notifyRecordingStopped() {
        postNotification(DarwinNotificationName.recordingStopped)
    }

    /// Notify that an error occurred (sent from main app)
    public func notifyRecordingError() {
        postNotification(DarwinNotificationName.recordingError)
    }

    // MARK: - Observing Notifications

    /// Add observer for a Darwin notification
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - callback: The callback to execute when notification is received
    public func addObserver(for name: String, callback: @escaping () -> Void) {
        // Create a context object to hold the callback
        let observer = Unmanaged.passRetained(DarwinNotificationCallback(callback: callback)).toOpaque()

        CFNotificationCenterAddObserver(
            darwinCenter,
            observer,
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

        // Keep reference to prevent deallocation
        observations.append(observer)
    }

    /// Remove observer for a Darwin notification
    public func removeObserver(for name: String) {
        CFNotificationCenterRemoveObserver(
            darwinCenter,
            nil,
            CFNotificationName(rawValue: name as CFString),
            nil
        )
    }

    /// Remove all observers
    public func removeAllObservers() {
        CFNotificationCenterRemoveEveryObserver(darwinCenter, nil)
        observations.removeAll()
    }

    // MARK: - Convenience Methods for Observing

    /// Observe start recording requests
    public func observeStartRecording(callback: @escaping () -> Void) {
        addObserver(for: DarwinNotificationName.startRecording, callback: callback)
    }

    /// Observe stop recording requests
    public func observeStopRecording(callback: @escaping () -> Void) {
        addObserver(for: DarwinNotificationName.stopRecording, callback: callback)
    }

    /// Observe transcription ready notifications
    public func observeTranscriptionReady(callback: @escaping () -> Void) {
        addObserver(for: DarwinNotificationName.transcriptionReady, callback: callback)
    }

    /// Observe recording started notifications
    public func observeRecordingStarted(callback: @escaping () -> Void) {
        addObserver(for: DarwinNotificationName.recordingStarted, callback: callback)
    }

    /// Observe recording stopped notifications
    public func observeRecordingStopped(callback: @escaping () -> Void) {
        addObserver(for: DarwinNotificationName.recordingStopped, callback: callback)
    }

    /// Observe recording error notifications
    public func observeRecordingError(callback: @escaping () -> Void) {
        addObserver(for: DarwinNotificationName.recordingError, callback: callback)
    }
}

// MARK: - Helper Class for Callbacks
private class DarwinNotificationCallback {
    let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func invoke() {
        callback()
    }
}
