//
//  WatchAudioRecorder.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import AVFoundation
import os

protocol WatchAudioRecorderProtocol {
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }
    func startRecording() throws -> URL
    func stopRecording() -> URL?
}

final class WatchAudioRecorder: NSObject, WatchAudioRecorderProtocol {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "AudioRecorder")

    private var audioRecorder: AVAudioRecorder?
    private var currentFileURL: URL?

    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }

    var currentTime: TimeInterval {
        audioRecorder?.currentTime ?? 0
    }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord)
        try session.setActive(true)

        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.record()

        audioRecorder = recorder
        currentFileURL = fileURL
        logger.info("Recording started: \(fileURL.lastPathComponent)")
        return fileURL
    }

    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else { return nil }
        recorder.stop()
        logger.info("Recording stopped: \(self.currentFileURL?.lastPathComponent ?? "nil")")

        let url = currentFileURL
        audioRecorder = nil
        currentFileURL = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }

        return url
    }
}

extension WatchAudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "AudioRecorder")
            logger.error("Recording finished unsuccessfully")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                            category: "AudioRecorder")
        logger.error("Recording encode error: \(error?.localizedDescription ?? "unknown")")
    }
}
