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

public final class AppGroupCoordinator {

}
