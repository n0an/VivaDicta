//
//  WatchConnectivityService.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import WatchConnectivity
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
        } else if pendingTransferCount > 0 {
            transferStatus = .transferring(count: pendingTransferCount)
        } else {
            transferStatus = .allUploaded
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
        let fileName = fileTransfer.file.fileURL.lastPathComponent
        let errorMessage = error?.localizedDescription
        Task { @MainActor in
            if let errorMessage {
                logger.error("File transfer failed: \(errorMessage)")
            } else {
                logger.info("File transfer completed: \(fileName)")
            }
            transferDidComplete(error: errorMessage)
        }
    }
}
