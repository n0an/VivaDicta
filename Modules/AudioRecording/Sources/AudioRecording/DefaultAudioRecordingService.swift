// Copyright © 2026 Anton Novoselov. All rights reserved.

@preconcurrency import AVFoundation
import AppGroup
import Foundation
import os

/// Production `AudioRecordingService` backed by `AVAudioRecorder`. Owns the
/// session activation, the recorder instance, and the delegate callbacks so
/// view models never have to import AVFoundation just to record.
@MainActor
public final class DefaultAudioRecordingService: NSObject, AudioRecordingService {

    private nonisolated let logger = Logger(
        subsystem: "com.antonnovoselov.VivaDicta",
        category: "AudioRecordingService"
    )

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var interruptionObserver: (any NSObjectProtocol)?

    /// Set while an interruption is closing the capture, so the delegate
    /// callback `stop()` provokes is not mistaken for a genuine failure.
    /// Cleared by the next `startRecording`, because the delegate hop runs after
    /// the interruption handler has already returned.
    private var isClosingForInterruption = false

    public var onDidFinishUnsuccessfully: (@MainActor () -> Void)?
    public var onInterruption: (@MainActor () -> Void)?

    public override init() {
        super.init()
    }

    public var isRecording: Bool {
        recorder?.isRecording ?? false
    }

    public var currentTime: TimeInterval {
        recorder?.currentTime ?? 0
    }

    public var currentAudioPower: Float {
        guard let recorder, recorder.isRecording else { return -160 }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    public func startRecording(to url: URL, settings: [String: Any]) throws {
        isClosingForInterruption = false
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            options: RecordingAudioSession.categoryOptions(base: [.defaultToSpeaker])
        )
        #if os(iOS)
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        #endif
        try session.setActive(true)
        // After activation - a preferred input set before it does not stick.
        RecordingAudioSession.applyPreferredInput(to: session)
        #endif

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                throw AudioRecordingError.failedToStart
            }
            self.recorder = recorder
            self.currentURL = url
            observeInterruptions()
            logger.info("Recording started: \(url.lastPathComponent, privacy: .public)")
        } catch {
            deactivateSessionQuietly()
            throw error
        }
    }

    public func stopRecording() -> URL? {
        stopObservingInterruptions()
        guard let recorder, recorder.isRecording else { return nil }
        recorder.stop()
        let finishedURL = currentURL
        self.recorder = nil
        self.currentURL = nil
        deactivateSessionQuietly()
        return finishedURL
    }

    private func deactivateSessionQuietly() {
        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    fileprivate func handleUnsuccessfulFinish() {
        // An interruption stops the recorder on purpose, and AVAudioRecorder may
        // report that stop as unsuccessful. Treating it as a failure here would
        // reset the UI out from under the interruption handler, which is busy
        // saving the partial recording.
        guard !isClosingForInterruption else {
            logger.info("Ignoring unsuccessful finish - the interruption handler owns this capture")
            return
        }
        logger.error("AVAudioRecorder finished unsuccessfully")
        self.recorder = nil
        self.currentURL = nil
        deactivateSessionQuietly()
        onDidFinishUnsuccessfully?()
    }
}

// MARK: - Interruptions

private extension DefaultAudioRecordingService {

    func observeInterruptions() {
        #if !os(macOS)
        stopObservingInterruptions()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            // The outer capture has to be weak too: an inner `[weak self]`
            // alone still makes this closure hold self strongly, which would
            // cycle through `interruptionObserver`.
            guard self != nil else { return }
            guard let info = notification.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw),
                  type == .began else {
                return
            }
            Task { @MainActor [weak self] in
                self?.handleInterruptionBegan()
            }
        }
        #endif
    }

    func stopObservingInterruptions() {
        guard let interruptionObserver else { return }
        NotificationCenter.default.removeObserver(interruptionObserver)
        self.interruptionObserver = nil
    }

    /// Closes the capture the system has already silenced.
    ///
    /// `AVAudioRecorder` is paused, not stopped, by an interruption, so the
    /// file on disk is still unfinalized - its WAV header claims a length that
    /// does not match the samples written. Calling `stop()` writes the real
    /// header, and only then is the partial recording readable by anything
    /// downstream. Nothing is resumed: a `.ended` notification arrives with the
    /// capture already closed, and stitching a second file onto the first is
    /// not worth the complexity for audio the user was interrupted out of
    /// anyway.
    func handleInterruptionBegan() {
        guard recorder != nil else { return }
        logger.info("Audio session interrupted - finalizing the partial recording")

        isClosingForInterruption = true
        recorder?.stop()
        recorder = nil
        currentURL = nil

        stopObservingInterruptions()
        deactivateSessionQuietly()

        onInterruption?()
    }
}

extension DefaultAudioRecordingService: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        Task { @MainActor [weak self] in
            self?.handleUnsuccessfulFinish()
        }
    }
}

public enum AudioRecordingError: Error {
    case failedToStart
}
