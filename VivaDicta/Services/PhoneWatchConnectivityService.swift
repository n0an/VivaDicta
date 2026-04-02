//
//  PhoneWatchConnectivityService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.02
//

import WatchConnectivity
import os

@Observable @MainActor
final class PhoneWatchConnectivityService: NSObject {
    private let logger = Logger(category: .watchConnectivity)

    /// Processor for transcribing watch audio in the background.
    private var audioProcessor: WatchAudioProcessor?

    func configure(audioProcessor: WatchAudioProcessor) {
        self.audioProcessor = audioProcessor
    }

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            logger.logInfo("WCSession not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        logger.logInfo("WCSession activating on iPhone")
    }

    private func processInBackground(audioURL: URL, sourceTag: String, recordingTimestamp: Date) {
        guard let audioProcessor else {
            logger.logError("WatchAudioProcessor not configured")
            return
        }

        Task {
            await audioProcessor.processAudioFile(
                at: audioURL,
                sourceTag: sourceTag,
                recordingTimestamp: recordingTimestamp
            )
        }
    }
}

extension PhoneWatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let logger = Logger(category: .watchConnectivity)
        if let error {
            logger.logError("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.logInfo("WCSession activated on iPhone: \(String(describing: activationState))")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        let logger = Logger(category: .watchConnectivity)
        logger.logInfo("WCSession became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        let logger = Logger(category: .watchConnectivity)
        logger.logInfo("WCSession deactivated, reactivating")
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let logger = Logger(category: .watchConnectivity)
        logger.logInfo("📲 Received wake message from watch")
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let sourceURL = file.fileURL
        let rawMetadata = file.metadata ?? [:]
        let logger = Logger(category: .watchConnectivity)

        logger.logInfo("📲 App woken up by WatchConnectivity to receive file: \(sourceURL.lastPathComponent)")

        let sourceTag = rawMetadata["sourceTag"] as? String ?? "appleWatch"
        let timestamp = rawMetadata["timestamp"] as? Double ?? Date().timeIntervalSince1970
        let recordingTimestamp = Date(timeIntervalSince1970: timestamp)

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDir = documentsDir.appending(path: "WatchAudio")

        do {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
            let destURL = audioDir.appending(path: "\(UUID().uuidString).wav")
            try FileManager.default.moveItem(at: sourceURL, to: destURL)
            logger.logInfo("Received watch audio: \(destURL.lastPathComponent)")

            Task { @MainActor in
                self.processInBackground(audioURL: destURL, sourceTag: sourceTag, recordingTimestamp: recordingTimestamp)
            }
        } catch {
            logger.logError("Failed to move watch audio file: \(error.localizedDescription)")
        }
    }
}
