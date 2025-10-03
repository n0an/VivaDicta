//
//  RecordingStateDetector.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation
import os

/// Detects the recording state in the main app using heartbeat mechanism
class RecordingStateDetector {

    // MARK: - Properties
    private let sharedDefaults: UserDefaults?
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardExtension")

    // MARK: - Initialization
    init() {
        sharedDefaults = UserDefaults(suiteName: AppGroupConfig.appGroupId)
        logger.info("🎤 💙 RecordingStateDetector initialized")
    }

    // MARK: - Public Methods

    /// Check if recording is currently active based on heartbeat
    func isRecordingActive() -> Bool {
        logger.info("🎤 💙 Checking recording state via heartbeat")

        guard let sharedDefaults = sharedDefaults else {
            logger.error("🎤 💙 ❌ Failed to access shared UserDefaults")
            return false
        }

        // Check the last recording heartbeat timestamp
        let lastHeartbeat = sharedDefaults.double(forKey: AppGroupConfig.recordingHeartbeatKey)

        // If heartbeat is 0, recording is not active
        guard lastHeartbeat > 0 else {
            logger.info("🎤 💙 Recording heartbeat is 0 - recording is not active")
            return false
        }

        // Calculate time since last heartbeat
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastHeartbeat = currentTime - lastHeartbeat

        // Check if heartbeat is recent enough
        if timeSinceLastHeartbeat < AppGroupConfig.recordingHeartbeatThreshold {
            logger.info("🎤 💙 Recording is active (heartbeat age: \(String(format: "%.1f", timeSinceLastHeartbeat))s)")
            return true
        } else {
            logger.info("🎤 💙 Recording is inactive (heartbeat age: \(String(format: "%.1f", timeSinceLastHeartbeat))s)")

            // Clear the stale recording flag
            sharedDefaults.set(false, forKey: "isRecording")
            sharedDefaults.synchronize()

            return false
        }
    }

    /// Get the age of the last recording heartbeat in seconds (for debugging)
    func recordingHeartbeatAge() -> TimeInterval? {
        guard let sharedDefaults = sharedDefaults else { return nil }

        let lastHeartbeat = sharedDefaults.double(forKey: AppGroupConfig.recordingHeartbeatKey)
        guard lastHeartbeat > 0 else { return nil }

        return Date().timeIntervalSince1970 - lastHeartbeat
    }
    
    /// Check if the recording flag is set (legacy check without heartbeat)
    func isRecordingFlagSet() -> Bool {
        guard let sharedDefaults = sharedDefaults else {
            logger.error("🎤 💙 ❌ Failed to access shared UserDefaults")
            return false
        }

        return sharedDefaults.bool(forKey: "isRecording")
    }
}
