//
//  WatchConnectivityService.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import WatchConnectivity
import WatchKit
import os

@Observable @MainActor
final class WatchConnectivityService: NSObject, WatchConnectivityServiceProtocol {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "WatchConnectivity")

    private let session: WatchSessionProtocol?

    private(set) var transferStatus: WatchTransferStatus = .idle
    private(set) var pendingTransferCount: Int = 0

    var isCompanionReachable: Bool {
        session?.isReachable ?? false
    }

    init(session: WatchSessionProtocol? = nil) {
        if let session {
            self.session = session
        } else if WCSession.isSupported() {
            self.session = WCSession.default
        } else {
            self.session = nil
        }
        super.init()

        if let wcSession = self.session as? WCSession {
            wcSession.delegate = self
            wcSession.activate()
            logger.info("WCSession activating")
        }
    }

    func transferAudioFile(at url: URL, metadata: [String: Any]) -> Bool {
        guard let session, session.activationState == .activated else {
            logger.error("WCSession not available or not activated")
            return false
        }

        session.transferFile(url, metadata: metadata)
        pendingTransferCount += 1
        transferStatus = .transferring(count: pendingTransferCount)
        logger.info("Queued file transfer: \(url.lastPathComponent), pending: \(self.pendingTransferCount)")
        return true
    }

    private func transferDidComplete(error: String?) {
        pendingTransferCount = max(pendingTransferCount - 1, 0)
        if let error {
            transferStatus = .error(error)
            WKInterfaceDevice.current().play(.failure)
        } else if pendingTransferCount > 0 {
            transferStatus = .transferring(count: pendingTransferCount)
        } else {
            transferStatus = .allUploaded
            WKInterfaceDevice.current().play(.success)
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let state = activationState
        Task { @MainActor in
            if let error {
                logger.error("WCSession activation failed: \(error.localizedDescription)")
            } else {
                logger.info("WCSession activated: \(String(describing: state))")
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: (any Error)?
    ) {
        let fileURL = fileTransfer.file.fileURL
        let fileName = fileURL.lastPathComponent
        let errorMessage = error?.localizedDescription

        // Clean up temp file after successful transfer
        if error == nil {
            try? FileManager.default.removeItem(at: fileURL)
        }

        Task { @MainActor in
            if let errorMessage {
                logger.error("File transfer failed: \(errorMessage)")
            } else {
                logger.info("File transfer completed: \(fileName)")
            }
            transferDidComplete(error: errorMessage)

            // Send a wake message to poke the iPhone app from suspended state
            if errorMessage == nil, let wcSession = self.session as? WCSession, wcSession.isReachable {
                wcSession.sendMessage(["wake": true], replyHandler: nil) { error in
                    // Silently ignore - sendMessage fails if iPhone is unreachable
                }
                logger.info("Sent wake message to iPhone")
            }
        }
    }
}
