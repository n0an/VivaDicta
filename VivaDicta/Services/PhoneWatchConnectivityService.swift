//
//  PhoneWatchConnectivityService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.02
//

import WatchConnectivity
import os

struct WatchAudioMetadata: Sendable {
    let sourceTag: String
    let timestamp: Double
    let duration: Double
}

@Observable @MainActor
final class PhoneWatchConnectivityService: NSObject {
    private let logger = Logger(category: .watchConnectivity)

    var onAudioFileReceived: ((_ fileURL: URL, _ metadata: WatchAudioMetadata) -> Void)?

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

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let sourceURL = file.fileURL
        let rawMetadata = file.metadata ?? [:]
        let logger = Logger(category: .watchConnectivity)

        // Extract Sendable values before crossing isolation boundary
        let sourceTag = rawMetadata["sourceTag"] as? String ?? "appleWatch"
        let timestamp = rawMetadata["timestamp"] as? Double ?? Date().timeIntervalSince1970
        let duration = rawMetadata["duration"] as? Double ?? 0

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDir = documentsDir.appending(path: "WatchAudio")

        do {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
            let destURL = audioDir.appending(path: "\(UUID().uuidString).wav")
            try FileManager.default.moveItem(at: sourceURL, to: destURL)
            logger.logInfo("Received watch audio: \(destURL.lastPathComponent)")

            let metadata = WatchAudioMetadata(
                sourceTag: sourceTag,
                timestamp: timestamp,
                duration: duration
            )

            Task { @MainActor in
                self.onAudioFileReceived?(destURL, metadata)
            }
        } catch {
            logger.logError("Failed to move watch audio file: \(error.localizedDescription)")
        }
    }
}
