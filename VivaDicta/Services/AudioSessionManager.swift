//
//  AudioSessionManager.swift
//  VivaDicta
//
//  Manages audio session lifecycle with configurable timeout
//  Prevents "session activation failed" errors by keeping session active between recordings
//

import Foundation
import AVFoundation
import SwiftUI
import os

@MainActor @Observable
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    var isSessionActive: Bool = false
    var timeoutRemaining: TimeInterval = 0

    private var deactivationTimer: Timer?
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AudioSessionManager")

    // Use computed property to access UserDefaults
    var audioSessionTimeout: Int {
        get {
            UserDefaults.standard.object(forKey: "audioSessionTimeout") as? Int ?? 180 // Default 3 minutes
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "audioSessionTimeout")
        }
    }

    private init() {}

    // MARK: - Public Interface

    /// Activates audio session for recording with optimal settings
    func activateSessionForRecording() throws {
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Configure session for recording with background support
            #if os(iOS)
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
            )
            #endif

            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            isSessionActive = true
            cancelScheduledDeactivation()

            logger.info("🎙️ Audio session activated for recording")

        } catch let error as NSError {
            logger.error("⚠️ Audio session activation failed: \(error.localizedDescription) (Code: \(error.code))")
            throw error
        }
        #else
        // macOS doesn't need session management
        isSessionActive = true
        cancelScheduledDeactivation()
        #endif
    }

    /// Schedules session deactivation after configured timeout
    func scheduleDeactivation() {
        cancelScheduledDeactivation()

        // If timeout is 0, deactivate immediately (legacy behavior)
        guard audioSessionTimeout > 0 else {
            deactivateSession()
            return
        }

        timeoutRemaining = TimeInterval(audioSessionTimeout)

        // Create timer that updates every second and deactivates when done
        deactivationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    return
                }

                self.timeoutRemaining -= 1

                if self.timeoutRemaining <= 0 {
                    self.deactivateSession()
                }
            }
        }

        logger.info("🕒 Audio session deactivation scheduled in \(self.audioSessionTimeout) seconds")
    }

    /// Extends the timeout period (called when new recording starts)
    func extendTimeout() {
        guard isSessionActive else { return }

        // Cancel current timer and reschedule
        scheduleDeactivation()
        logger.info("⏰ Audio session timeout extended")
    }

    /// Immediately deactivates the session
    func deactivateSession() {
        cancelScheduledDeactivation()

        guard isSessionActive else { return }

        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
            timeoutRemaining = 0
            logger.info("🔇 Audio session deactivated")
        } catch {
            logger.error("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #else
        isSessionActive = false
        timeoutRemaining = 0
        #endif
    }

    // MARK: - Private Methods

    private func cancelScheduledDeactivation() {
        deactivationTimer?.invalidate()
        deactivationTimer = nil
        timeoutRemaining = 0
    }

    
}
