//
//  AudioPrewarmManager.swift
//  VivaDicta
//
//  Manages audio pre-warming session for keyboard recording
//  Uses continuous dummy recorder + parallel real recorder approach
//

import Foundation
import AVFoundation
import os

@Observable
final class AudioPrewarmManager {
    
    static let shared = AudioPrewarmManager()
    
    // MARK: - Properties
    
    
    var audioSessionTimeout: Int {
        get {
            UserDefaultsStorage.appPrivate.object(forKey: "audioSessionTimeout") as? Int ?? 180 // Default 3 minutes
        }
        set {
            UserDefaultsStorage.appPrivate.set(newValue, forKey: "audioSessionTimeout")
        }
    }

    private var dummyRecorder: AVAudioRecorder?
    private var realRecorder: AVAudioRecorder?
    private var sessionStartTime: Date?
    private var sessionTimeoutDuration: TimeInterval = AppGroupCoordinator.audioPrewarmSessionTimeout
    private var expiryTimer: Timer?
    private var dummyFileURL: URL?

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AudioPrewarmManager")

    var isSessionActive: Bool {
        dummyRecorder?.isRecording == true && isWithinSessionTimeout()
    }

    var timeoutRemaining: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, sessionTimeoutDuration - elapsed)
    }

    /// Public getter for real recorder (for metering in RecordViewModel)
    var activeRealRecorder: AVAudioRecorder? {
        realRecorder
    }

    private init() {}

    // MARK: - Session Management

    /// Starts pre-warm session - activates audio session and starts continuous dummy recorder
    /// - Parameter timeout: Session duration in seconds (uses AudioSessionManager timeout if not specified)
    func startPrewarmSession(timeout: TimeInterval? = nil) throws {
        // If session is already active, just extend it
        if isSessionActive {
            logger.info("🎙️ Prewarm session already active, extending timeout")
            extendSession(timeout: timeout)
            return
        }

        // Use AudioSessionManager timeout if not specified
        let sessionTimeout = timeout ?? TimeInterval(audioSessionTimeout)
        sessionStartTime = Date()
        sessionTimeoutDuration = sessionTimeout

        logger.info("🎙️ Starting prewarm session (timeout: \(sessionTimeout)s)")

        // Configure audio session
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.mixWithOthers, .allowBluetoothHFP, .defaultToSpeaker]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // Start continuous dummy recorder
        try startDummyRecording()

        // Setup session timeout
        scheduleSessionTimeout()

        logger.info("🎙️ Prewarm session started successfully")
    }

    /// Extends the current session timeout (called from deeplink if session already active)
    private func extendSession(timeout: TimeInterval?) {
        guard isSessionActive else { return }

        let newTimeout = timeout ?? TimeInterval(audioSessionTimeout)
        sessionStartTime = Date()
        sessionTimeoutDuration = newTimeout

        // Reschedule timeout
        scheduleSessionTimeout()

        logger.info("🎙️ Prewarm session extended (new timeout: \(newTimeout)s)")
    }

    /// Ends the prewarm session and cleans up all resources
    func endSession() {
        logger.info("🎙️ Ending prewarm session")

        dummyRecorder?.stop()
        realRecorder?.stop()
        dummyRecorder = nil
        realRecorder = nil

        expiryTimer?.invalidate()
        expiryTimer = nil

        sessionStartTime = nil

        // Clean up dummy file
        if let url = dummyFileURL {
            cleanupDummyFile(url)
            dummyFileURL = nil
        }

        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif

        logger.info("🎙️ Prewarm session ended")
    }

    // MARK: - Dummy Recorder (Continuous)

    private func startDummyRecording() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dummy_\(Date().timeIntervalSince1970).m4a")

        dummyFileURL = tempURL

        // Use EXACT SAME settings as RecordViewModel for consistency
        // This ensures both recorders can coexist without format conflicts
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        dummyRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
        dummyRecorder?.record()

        logger.info("🎙️ Dummy recorder started (keeps app alive, orange dot visible)")
    }

    private func scheduleSessionTimeout() {
        expiryTimer?.invalidate()

        expiryTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeoutDuration, repeats: false) { [weak self] _ in
            
            Task { @MainActor [weak self] in
                self?.logger.info("⏰ Prewarm session timeout reached")
                self?.endSession()
            }
        }

        logger.info("⏰ Session timeout scheduled for \(self.sessionTimeoutDuration)s from now")
    }

    // MARK: - Real Recorder (Parallel)

    /// Starts real recording in parallel with dummy recorder
    /// - Parameter url: URL to save the real recording
    func startRealCapture(to url: URL) throws {
        guard isWithinSessionTimeout() else {
            throw PrewarmError.sessionExpired
        }

        logger.info("🎙️ Starting real capture (dummy keeps running)")

        // IMPORTANT: Don't stop dummy recorder - it keeps running!
        // Use SAME settings as RecordViewModel normal flow for compatibility
        let settings: [String : Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        realRecorder = try AVAudioRecorder(url: url, settings: settings)
        realRecorder?.isMeteringEnabled = true  // Enable metering for visualization
        realRecorder?.record()

        logger.info("🎙️ Real recorder started (parallel with dummy)")
    }

    /// Stops real recording (dummy continues running)
    func stopRealCapture() {
        logger.info("🎙️ Stopping real capture (dummy continues)")

        realRecorder?.stop()
        realRecorder = nil

        // Dummy keeps running - no switching, no orange dot disappearing
        // Session continues until timeout
    }

    // MARK: - Private Helpers

    private func isWithinSessionTimeout() -> Bool {
        guard let startTime = sessionStartTime else { return false }
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed < sessionTimeoutDuration
    }

    private func cleanupDummyFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("🗑️ Cleaned up dummy recording file")
        } catch {
            logger.error("⚠️ Failed to cleanup dummy file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

enum PrewarmError: Error {
    case sessionExpired
    case recorderNotActive
}
