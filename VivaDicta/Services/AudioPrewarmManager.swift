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
@preconcurrency import AVFAudio

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
    private var expiryTimer: Timer?
    private var dummyFileURL: URL?
    
    var audioEngine: AVAudioEngine?
    private var isCapturing = false
    private var audioFile: AVAudioFile?
    private var captureContext: AudioCaptureContext?

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AudioPrewarmManager")

    var isSessionActive: Bool {
        // Session is active if dummy recorder is running AND either:
        // 1. We're within the timeout period, OR
        // 2. Real recording is currently active (no timeout during real recording)
        dummyRecorder?.isRecording == true &&
        (isWithinSessionTimeout() || realRecorder?.isRecording == true)
    }

    var timeoutRemaining: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, TimeInterval(audioSessionTimeout) - elapsed)
    }

    /// Public getter for real recorder (for metering in RecordViewModel)
    var activeRealRecorder: AVAudioRecorder? {
        realRecorder
    }

    private init() {}

    // MARK: - Session Management

    /// Starts pre-warm session - activates audio session and starts continuous dummy recorder
    /// - Parameter timeout: Session duration in seconds (uses configured timeout if not specified)
    func startPrewarmSession(timeout: TimeInterval? = nil) throws {
        // If session is already active, just extend it
        if isSessionActive {
            logger.info("🎙️ Prewarm session already active, extending timeout")
            extendSession(timeout: timeout)
            return
        }

        // Update timeout if specified, otherwise use existing setting
        if let timeout = timeout {
            audioSessionTimeout = Int(timeout)
        }
        sessionStartTime = Date()

        logger.info("🎙️ Starting prewarm session (timeout: \(self.audioSessionTimeout)s)")

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
        Task {
            
            try await startDummyRecording()
        }

        // Setup session timeout
        scheduleSessionTimeout()

        logger.info("🎙️ Prewarm session started successfully")
    }

    /// Extends the current session timeout (called from deeplink if session already active)
    private func extendSession(timeout: TimeInterval?) {
        guard isSessionActive else { return }

        // Update timeout if specified
        if let timeout = timeout {
            audioSessionTimeout = Int(timeout)
        }
        sessionStartTime = Date()

        // Reschedule timeout
        scheduleSessionTimeout()

        logger.info("🎙️ Prewarm session extended (new timeout: \(self.audioSessionTimeout)s)")
    }

    /// Ends the prewarm session and cleans up all resources
    func endSession() {
        logger.info("🎙️ Ending prewarm session")

        // Stop capturing if active
        captureContext?.isCapturing = false
        captureContext?.audioFile = nil
        captureContext = nil

        // Stop audio engine
        audioEngine?.stop()
        audioEngine = nil

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

        // Deactivate keyboard session to notify keyboard that hot mic has ended
        AppGroupCoordinator.shared.deactivateKeyboardSession()

        logger.info("🎙️ Prewarm session and keyboard session ended")
    }

    // MARK: - Dummy Recorder (Continuous)

    private func startDummyRecording() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dummy_\(Date().timeIntervalSince1970).m4a")

        dummyFileURL = tempURL

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw PrewarmError.recorderNotActive
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Create capture context for controlling real recordings
        let captureContext = AudioCaptureContext()
        self.captureContext = captureContext

        // Install tap on background queue to avoid inheriting actor context
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                installInputTapNonisolated(
                    inputNode: inputNode,
                    format: recordingFormat,
                    captureContext: captureContext
                )
                continuation.resume()
            }
        }

        // Start the audio engine
        try audioEngine.start()

        logger.info("🎙️ Dummy audio engine started (tap installed, ready for real capture)")
    }

    private func scheduleSessionTimeout() {
        expiryTimer?.invalidate()

        expiryTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(audioSessionTimeout), repeats: false) { [weak self] _ in

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Simply end the session when timeout is reached
                // Real recording will have already invalidated this timer if active
                self.logger.info("⏰ Prewarm session timeout reached - ending session")
                self.endSession()
            }
        }

        logger.info("⏰ Session timeout scheduled for \(self.audioSessionTimeout)s from now")
    }

    // MARK: - Real Recorder (Parallel)

    /// Starts real recording in parallel with dummy recorder
    /// - Parameter url: URL to save the real recording
    func startRealCapture(to url: URL) throws {
        guard isWithinSessionTimeout() else {
            throw PrewarmError.sessionExpired
        }

        guard let captureContext = captureContext else {
            throw PrewarmError.recorderNotActive
        }

        guard let audioEngine = audioEngine else {
            throw PrewarmError.recorderNotActive
        }

        logger.info("🎙️ Starting real capture to file (audio already flowing through tap)")

        // Invalidate timeout timer while real recording is active
        expiryTimer?.invalidate()
        expiryTimer = nil
        logger.info("⏰ Invalidated timeout - will continue indefinitely while recording")

        // Create audio file for the real recording
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)

        // Atomically start capturing to the new file
        captureContext.audioFile = audioFile
        captureContext.isCapturing = true

        logger.info("🎙️ Real capture started (buffers now writing to disk)")
    }

    /// Stops real recording and restarts the pre-warm session timeout
    func stopRealCapture() {
        logger.info("🎙️ Stopping real capture and restarting session timeout")

        // Stop writing to file atomically
        captureContext?.isCapturing = false
        captureContext?.audioFile = nil

        // Audio engine keeps running (no check needed)
        guard audioEngine?.isRunning == true else {
            logger.error("❌ Unexpected: Audio engine not running after real recording!")

            do {
                try startPrewarmSession()
                logger.info("🔧 Recovery: Successfully restarted pre-warm session")
            } catch {
                logger.error("❌ Recovery failed: \(error.localizedDescription)")
            }
            return
        }

        // Reset the session start time
        sessionStartTime = Date()

        // Restart the timeout timer
        scheduleSessionTimeout()

        // Refresh keyboard session expiry
        AppGroupCoordinator.shared.refreshKeyboardSessionExpiry(
            timeoutSeconds: audioSessionTimeout
        )

        logger.info("🎙️ Restarted pre-warm session timeout: \(self.audioSessionTimeout)s from now")
    }

    // MARK: - Private Helpers

    private func isWithinSessionTimeout() -> Bool {
        guard let startTime = sessionStartTime else { return false }
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed < TimeInterval(audioSessionTimeout)
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




nonisolated private func installInputTapNonisolated(
    inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    captureContext: AudioCaptureContext
) {
    let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "installInputTapNonisolated")

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        // This runs on audio thread - context handles thread-safety
        captureContext.writeBufferIfCapturing(buffer)
    }

    logger.info("🎙️ Input tap installed on audio thread")
}



/// Thread-safe capture context for audio recording
nonisolated private final class AudioCaptureContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCapturing = false
    private var _audioFile: AVAudioFile?

    nonisolated init() {}

    var isCapturing: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isCapturing
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isCapturing = newValue
        }
    }

    var audioFile: AVAudioFile? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _audioFile
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _audioFile = newValue
        }
    }

    nonisolated func writeBufferIfCapturing(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        guard _isCapturing, let file = _audioFile else { return }

        do {
            try file.write(from: buffer)
        } catch {
            // Log error but don't crash audio thread
            print("Failed to write audio buffer: \(error)")
        }
    }
}
