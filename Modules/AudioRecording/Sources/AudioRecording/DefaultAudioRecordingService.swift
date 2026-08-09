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

    public var onDidFinishUnsuccessfully: (@MainActor () -> Void)?

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
            logger.info("Recording started: \(url.lastPathComponent, privacy: .public)")
        } catch {
            deactivateSessionQuietly()
            throw error
        }
    }

    public func stopRecording() -> URL? {
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
        logger.error("AVAudioRecorder finished unsuccessfully")
        self.recorder = nil
        self.currentURL = nil
        deactivateSessionQuietly()
        onDidFinishUnsuccessfully?()
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
