//
//  WatchRecordViewModel.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import Foundation
import WatchKit
import os

@Observable @MainActor
final class WatchRecordViewModel {
    enum RecordingState {
        case idle
        case recording
    }

    private let connectivityService: WatchConnectivityServiceProtocol
    private let audioRecorder: WatchAudioRecorderProtocol
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "RecordViewModel")

    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    private(set) var state: RecordingState = .idle
    private(set) var recordingDuration: TimeInterval = 0

    var transferStatus: WatchTransferStatus {
        connectivityService.transferStatus
    }

    var pendingCount: Int {
        connectivityService.pendingTransferCount
    }

    init(connectivityService: WatchConnectivityServiceProtocol,
         audioRecorder: WatchAudioRecorderProtocol) {
        self.connectivityService = connectivityService
        self.audioRecorder = audioRecorder
    }

    func toggleRecording() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        }
    }

    private func startRecording() {
        do {
            _ = try audioRecorder.startRecording()
            state = .recording
            recordingStartTime = Date()
            recordingDuration = 0
            startDurationTimer()
            WKInterfaceDevice.current().play(.start)
            logger.info("Recording started")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        stopDurationTimer()

        guard let fileURL = audioRecorder.stopRecording() else {
            logger.error("No file URL from recorder")
            state = .idle
            return
        }

        let metadata: [String: Any] = [
            "sourceTag": "appleWatch",
            "timestamp": Date().timeIntervalSince1970,
            "duration": recordingDuration
        ]

        WKInterfaceDevice.current().play(.stop)

        let success = connectivityService.transferAudioFile(at: fileURL, metadata: metadata)
        if !success {
            logger.error("Failed to queue file transfer")
        }

        state = .idle
        recordingDuration = 0
        logger.info("Recording stopped and queued for transfer")
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
