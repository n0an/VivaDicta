//
//  AudioPrewarmManager.swift
//  VivaDicta
//
//  Manages audio pre-warming session for keyboard recording
//  Uses continuous AVAudioEngine with installTap
//  Switches between discarding buffers (armed) and writing to file (capturing)
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
            UserDefaultsStorage.appPrivate.object(forKey: UserDefaultsStorage.Keys.audioSessionTimeout) as? Int ?? 180 // Default 3 minutes
        }
        set {
            UserDefaultsStorage.appPrivate.set(newValue, forKey: UserDefaultsStorage.Keys.audioSessionTimeout)
        }
    }

    private var sessionStartTime: Date?
    private var expiryTimer: Timer?

    var audioEngine: AVAudioEngine?
    private var captureContext: AudioCaptureContext?

    // Audio level for visualization (0.0 to 1.0)
    private(set) var currentAudioLevel: Float = 0.0

    // Observable property for session state
    private(set) var isSessionActiveObservable: Bool = false

    private let logger = Logger(category: .audioPrewarmManager)

    /// Returns true if the prewarm session is active
    /// - Session is active if audio engine is running AND either:
    ///   1. We're within the timeout period, OR
    ///   2. Real recording is currently active (no timeout during real recording)
    var isSessionActive: Bool {
        audioEngine?.isRunning == true &&
        (isWithinSessionTimeout() || captureContext?.isCapturing == true)
    }

    var timeoutRemaining: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, TimeInterval(audioSessionTimeout) - elapsed)
    }

    private init() {}

    // MARK: - Session Management

    /// Starts pre-warm session - activates audio session and starts continuous dummy recorder
    /// - Parameter timeout: Session duration in seconds (uses configured timeout if not specified)
    func startPrewarmSession(timeout: TimeInterval? = nil) async throws {
        // If session is already active, just extend it
        if isSessionActive {
            // Don't extend if we're actively recording
            if captureContext?.isCapturing == true {
                logger.logInfo("🎙️ Prewarm session already active with recording - no action needed")
                return
            }
            logger.logInfo("🎙️ Prewarm session already active, extending timeout")
            extendSession(timeout: timeout)
            return
        }

        // Update timeout if specified, otherwise use existing setting
        if let timeout = timeout {
            audioSessionTimeout = Int(timeout)
        }
        sessionStartTime = Date()

        logger.logInfo("🎙️ Starting prewarm session (timeout: \(self.audioSessionTimeout)s)")

        // Configure audio session
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.mixWithOthers, .allowBluetoothHFP, .defaultToSpeaker]
        )
        try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try audioSession.setActive(true)
        #endif

        // Start continuous dummy recorder and wait for it to complete
        try await startDummyRecording()

        // Setup session timeout
        scheduleSessionTimeout()

        // Update observable state
        isSessionActiveObservable = true

        logger.logInfo("🎙️ Prewarm session started successfully")
    }

    /// Extends the current session timeout (called from deeplink if session already active)
    private func extendSession(timeout: TimeInterval?) {
        guard isSessionActive else { return }

        // Don't reschedule timeout if we're actively recording
        if captureContext?.isCapturing == true {
            logger.logInfo("🎙️ Prewarm session extend request ignored - recording in progress")
            return
        }

        // Update timeout if specified
        if let timeout = timeout {
            audioSessionTimeout = Int(timeout)
        }
        sessionStartTime = Date()

        // Reschedule timeout
        scheduleSessionTimeout()

        logger.logInfo("🎙️ Prewarm session extended (new timeout: \(self.audioSessionTimeout)s)")
    }

    /// Ends the prewarm session and cleans up all resources
    func endSession() {
        logger.logInfo("🎙️ Ending prewarm session")

        // Stop capturing if active
        captureContext?.isCapturing = false
        captureContext?.audioFile = nil
        captureContext = nil

        // Stop audio engine
        audioEngine?.stop()
        audioEngine = nil

        expiryTimer?.invalidate()
        expiryTimer = nil

        sessionStartTime = nil

        // Update observable state
        isSessionActiveObservable = false

        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.logError("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif

        // Deactivate keyboard session to notify keyboard that hot mic has ended
        AppGroupCoordinator.shared.deactivateKeyboardSession()

        logger.logInfo("🎙️ Prewarm session and keyboard session ended")
    }

    // MARK: - Audio Engine (Continuous)

    private func startDummyRecording() async throws {
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
                    captureContext: captureContext,
                    onLevelUpdate: { [weak self] level in
                        Task { @MainActor [weak self] in
                            self?.currentAudioLevel = level
                        }
                    }
                )
                continuation.resume()
            }
        }

        // Start the audio engine
        try audioEngine.start()

        logger.logInfo("🎙️ Audio engine started (tap installed, ready for real capture)")
    }

    private func scheduleSessionTimeout() {
        expiryTimer?.invalidate()

        expiryTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(audioSessionTimeout), repeats: false) { [weak self] _ in

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Simply end the session when timeout is reached
                // Real recording will have already invalidated this timer if active
                self.logger.logInfo("⏰ Prewarm session timeout reached - ending session")
                self.endSession()
            }
        }

        logger.logInfo("⏰ Session timeout scheduled for \(self.audioSessionTimeout)s from now")
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

        guard let audioEngine = audioEngine, audioEngine.isRunning else {
            throw PrewarmError.recorderNotActive
        }

        logger.logInfo("🎙️ Starting real capture to file (audio already flowing through tap)")

        // Invalidate timeout timer while real recording is active
        expiryTimer?.invalidate()
        expiryTimer = nil
        logger.logInfo("⏰ Invalidated timeout - will continue indefinitely while recording")

        // Get the actual format from the audio engine's input node
        let inputNode = audioEngine.inputNode
        let engineFormat = inputNode.outputFormat(forBus: 0)

        // Check if format is float or integer
        let isFloat = engineFormat.commonFormat == .pcmFormatFloat32 ||
                      engineFormat.commonFormat == .pcmFormatFloat64

        logger.logInfo("🎙️ Engine format: \(engineFormat.sampleRate)Hz, \(engineFormat.channelCount) channels, isFloat: \(isFloat), commonFormat: \(engineFormat.commonFormat.rawValue)")

        // Create settings based on engine's actual format to avoid sample rate mismatch
        // Use the engine's native sample rate and format
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: engineFormat.sampleRate,
            AVNumberOfChannelsKey: engineFormat.channelCount,
            AVLinearPCMBitDepthKey: isFloat ? 32 : 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: isFloat
        ]

        let audioFile = try AVAudioFile(forWriting: url, settings: settings)

        // Atomically start capturing to the new file
        captureContext.audioFile = audioFile
        captureContext.isCapturing = true

        logger.logInfo("🎙️ Real capture started (buffers now writing to disk)")
    }

    /// Stops real recording without restarting timeout (processing will follow)
    /// Call `rescheduleSessionTimeout()` after all processing is complete
    func stopRealCapture() {
        logger.logInfo("🎙️ Stopping real capture (timeout deferred until processing completes)")

        // Stop writing to file atomically
        captureContext?.isCapturing = false
        captureContext?.audioFile = nil

        // Audio engine keeps running (no check needed)
        guard audioEngine?.isRunning == true else {
            logger.logError("❌ Unexpected: Audio engine not running after real recording!")

            Task {
                do {
                    try await startPrewarmSession()
                    logger.logInfo("🔧 Recovery: Successfully restarted pre-warm session")
                } catch {
                    logger.logError("❌ Recovery failed: \(error.localizedDescription)")
                }
            }
            return
        }

        // Note: We do NOT restart the timeout timer here
        // The caller should call rescheduleSessionTimeout() after processing is complete
        // This prevents the session from expiring during transcription/enhancement

        logger.logInfo("🎙️ Real capture stopped, audio engine still running (awaiting processing completion)")
    }

    /// Reschedules the session timeout after all processing is complete
    /// Should be called when transcription and enhancement are finished
    func rescheduleSessionTimeout() {
        guard audioEngine?.isRunning == true else {
            logger.logInfo("⏰ Session not active, skipping timeout reschedule")
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

        logger.logInfo("🎙️ Session timeout rescheduled: \(self.audioSessionTimeout)s from now")
    }

    // MARK: - Private Helpers

    private func isWithinSessionTimeout() -> Bool {
        guard let startTime = sessionStartTime else { return false }
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed < TimeInterval(audioSessionTimeout)
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
    captureContext: AudioCaptureContext,
    onLevelUpdate: @escaping (Float) -> Void
) {
    let logger = Logger(category: .installInputTapNonisolated)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        // This runs on audio thread - context handles thread-safety
        captureContext.writeBufferIfCapturing(buffer, updateLevel: onLevelUpdate)
    }

    logger.logError("🎙️ Input tap installed on audio thread")
}

/// Thread-safe capture context for audio recording
nonisolated private final class AudioCaptureContext: @unchecked Sendable {
    private let lock = NSLock()
    private let logger = Logger(category: .audioPrewarmManager)
    private var _isCapturing = false
    private var _audioFile: AVAudioFile?
    private var _currentAudioLevel: Float = 0.0

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

    var currentAudioLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return _currentAudioLevel
    }

    nonisolated func writeBufferIfCapturing(_ buffer: AVAudioPCMBuffer, updateLevel: @escaping (Float) -> Void) {
        // Calculate audio level from PCM buffer
        let level = calculateAudioLevel(from: buffer)

        // Update level immediately (outside lock to avoid potential issues)
        updateLevel(level)

        // Now handle file writing with lock
        lock.lock()
        defer { lock.unlock() }

        _currentAudioLevel = level

        guard _isCapturing, let file = _audioFile else { return }

        do {
            try file.write(from: buffer)
        } catch {
            // Log error but don't crash audio thread
            logger.logError("Failed to write audio buffer: \(error.localizedDescription)")
        }
    }

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        // Try float32 format first (most common for AVAudioEngine)
        if let floatData = buffer.floatChannelData {
            let channelData = floatData.pointee
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) {
                let sample = channelData[i]
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)
            // Normalize to 0...1 range (assuming -50dB to 0dB range)
            let normalizedPower = max(0, min(1, 1 - abs(avgPower / 50)))
            return normalizedPower
        }

        // Fallback to int16 format
        if let int16Data = buffer.int16ChannelData {
            let channelData = int16Data.pointee
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) {
                let sample = Float(channelData[i]) / 32768.0  // Normalize to -1.0...1.0
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)
            // Normalize to 0...1 range (assuming -50dB to 0dB range)
            let normalizedPower = max(0, min(1, 1 - abs(avgPower / 50)))
            return normalizedPower
        }

        return 0
    }
}
