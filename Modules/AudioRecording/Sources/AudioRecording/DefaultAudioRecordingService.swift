// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
import Foundation
import os

/// Production `AudioRecordingService` backed by `AVAudioRecorder`. Owns the
/// session activation, the recorder instance, and the delegate callbacks so
/// view models never have to import AVFoundation just to record.
@MainActor
public final class DefaultAudioRecordingService: NSObject, AudioRecordingService {

    private let logger = Logger(
        subsystem: "com.antonnovoselov.VivaDicta",
        category: "AudioRecordingService"
    )

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

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
        try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        #if os(iOS)
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        #endif
        try session.setActive(true)
        #endif

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw AudioRecordingError.failedToStart
        }

        self.recorder = recorder
        self.currentURL = url
        logger.info("Recording started: \(url.lastPathComponent, privacy: .public)")
    }

    public func stopRecording() -> URL? {
        guard let recorder, recorder.isRecording else { return nil }
        recorder.stop()
        let finishedURL = currentURL
        self.recorder = nil
        self.currentURL = nil

        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
        #endif

        return finishedURL
    }
}

extension DefaultAudioRecordingService: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            let logger = Logger(
                subsystem: "com.antonnovoselov.VivaDicta",
                category: "AudioRecordingService"
            )
            logger.error("AVAudioRecorder finished unsuccessfully")
        }
    }
}

public enum AudioRecordingError: Error {
    case failedToStart
}
