//
//  PhoneWatchConnectivityService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.02
//

import UIKit
import WatchConnectivity
import os

@Observable @MainActor
final class PhoneWatchConnectivityService: NSObject {
    private let logger = Logger(category: .watchConnectivity)

    /// Processor for transcribing watch audio in the background.
    private var audioProcessor: WatchAudioProcessor?

    /// Service for background task protection.
    private var backgroundTaskService: BackgroundTaskService?

    /// Modes to sync to watch once session activates.
    private var pendingModes: [VivaMode]?

    func configure(audioProcessor: WatchAudioProcessor, backgroundTaskService: BackgroundTaskService) {
        self.audioProcessor = audioProcessor
        self.backgroundTaskService = backgroundTaskService
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

    /// Sends the current list of Viva Modes to the watch via application context.
    func syncModesToWatch(modes: [VivaMode]) {
        guard WCSession.default.activationState == .activated else {
            // Session not ready yet - queue for when it activates
            pendingModes = modes
            logger.logInfo("WCSession not activated yet, queuing \(modes.count) modes for sync")
            return
        }

        sendModesContext(modes)
    }

    private func sendModesContext(_ modes: [VivaMode]) {
        let modeData = modes.map { mode in
            [
                "id": mode.id.uuidString,
                "name": mode.name
            ]
        }

        // Use both: applicationContext for persistence, transferUserInfo for guaranteed delivery
        do {
            try WCSession.default.updateApplicationContext(["modes": modeData])
            logger.logInfo("Synced \(modes.count) modes to watch via applicationContext")
        } catch {
            logger.logError("Failed to sync modes via applicationContext: \(error.localizedDescription)")
        }

        WCSession.default.transferUserInfo(["modes": modeData])
        logger.logInfo("Synced \(modes.count) modes to watch via transferUserInfo")
    }

    private func processInBackground(audioURL: URL, sourceTag: String, recordingTimestamp: Date, modeId: String?) {
        guard let audioProcessor else {
            logger.logError("WatchAudioProcessor not configured")
            return
        }

        let fileName = audioURL.lastPathComponent

        // Proactively enqueue and schedule BGProcessingTask before starting work.
        // This guarantees the fallback is in the system before any time pressure.
        // If processing succeeds, we remove from queue and cancel the BGTask.
        backgroundTaskService?.enqueueForLaterProcessing(
            audioURL: audioURL,
            sourceTag: sourceTag,
            modeId: modeId,
            recordingTimestamp: recordingTimestamp
        )

        // Begin background task to prevent iOS from suspending during processing
        let bgTaskID = backgroundTaskService?.beginBackgroundTask(
            name: "watch-audio-\(fileName)",
            onExpiration: {
                // No need to enqueue here - already done above
            }
        ) ?? .invalid

        Task {
            await audioProcessor.processAudioFile(
                at: audioURL,
                sourceTag: sourceTag,
                recordingTimestamp: recordingTimestamp,
                modeId: modeId
            )
            // On success, remove from queue and cancel the BGProcessingTask
            backgroundTaskService?.removeFromQueueIfProcessed(audioFileName: fileName)
            backgroundTaskService?.endBackgroundTask(bgTaskID)
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
            Task { @MainActor in
                if let pendingModes = self.pendingModes {
                    self.pendingModes = nil
                    self.sendModesContext(pendingModes)
                }
            }
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
        let modeId = rawMetadata["modeId"] as? String
        let duration = rawMetadata["duration"] as? Double

        let audioDir = URL.documentsDirectory.appending(path: "Audio")

        do {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
            let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
            let destURL = audioDir.appending(path: "watch-\(UUID().uuidString).\(ext)")
            try FileManager.default.moveItem(at: sourceURL, to: destURL)
            logger.logInfo("Received watch audio: \(destURL.lastPathComponent)")

            AnalyticsService.track(.watchRecordingReceived(
                durationSeconds: duration,
                hasModeId: modeId != nil
            ))

            Task { @MainActor in
                self.processInBackground(audioURL: destURL, sourceTag: sourceTag, recordingTimestamp: recordingTimestamp, modeId: modeId)
            }
        } catch {
            logger.logError("Failed to move watch audio file: \(error.localizedDescription)")
        }
    }
}
