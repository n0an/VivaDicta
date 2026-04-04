//
//  WatchConnectivityService.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import SwiftUI
import WatchConnectivity
import WatchKit
import os

@Observable @MainActor
final class WatchConnectivityService: NSObject, WatchConnectivityServiceProtocol {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "WatchConnectivity")

    private let session: WCSession?
    private let defaults: UserDefaults

    private static let cachedModesKey = "cachedWatchModes"

    private(set) var transferStatus: WatchTransferStatus = .idle
    private(set) var pendingTransferCount: Int = 0
    private(set) var availableModes: [WatchModeInfo] = [] {
        didSet {
            // Cache modes to UserDefaults for next launch
            if !availableModes.isEmpty {
                let data = availableModes.map { ["id": $0.id, "name": $0.name] }
                defaults.set(data, forKey: Self.cachedModesKey)
            }
        }
    }

    var isCompanionReachable: Bool {
        session?.isReachable ?? false
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()

        if let session {
            session.delegate = self
            session.activate()
            logger.info("WCSession activating")

            // Restore pending transfer count from previous session
            let outstanding = session.outstandingFileTransfers.count
            if outstanding > 0 {
                pendingTransferCount = outstanding
                transferStatus = .transferring(count: outstanding)
            }

            // Load cached modes first, then try application context
            loadCachedModes()
            parseModes(from: session.receivedApplicationContext)
        }
    }

    private func loadCachedModes() {
        guard let data = defaults.array(forKey: Self.cachedModesKey) as? [[String: String]] else { return }
        availableModes = data.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return WatchModeInfo(id: id, name: name)
        }
        if !availableModes.isEmpty {
            logger.info("Loaded \(self.availableModes.count) cached modes")
        }
    }

    func parseModes(from context: [String: Any]) {
        guard let modesData = context["modes"] as? [[String: String]] else {
            logger.info("No modes key in context, keys: \(Array(context.keys))")
            return
        }
        availableModes = modesData.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return WatchModeInfo(id: id, name: name)
        }
        logger.info("Loaded \(self.availableModes.count) modes: \(self.availableModes.map(\.name))")
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
        withAnimation(.easeInOut(duration: 0.3)) {
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
        if case .allUploaded = transferStatus {
            Task {
                try? await Task.sleep(for: .seconds(2))
                if case .allUploaded = self.transferStatus {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.transferStatus = .idle
                    }
                }
            }
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
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleModesPayload(applicationContext, source: "applicationContext")
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleModesPayload(userInfo, source: "transferUserInfo")
    }

    nonisolated private func handleModesPayload(_ payload: [String: Any], source: String) {
        guard let modesData = payload["modes"] as? [[String: String]] else { return }
        let modes = modesData.compactMap { dict -> WatchModeInfo? in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return WatchModeInfo(id: id, name: name)
        }
        guard !modes.isEmpty else { return }
        Task { @MainActor in
            self.availableModes = modes
            self.logger.info("Received \(modes.count) modes via \(source)")
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
            if errorMessage == nil, let session = self.session, session.isReachable {
                session.sendMessage(["wake": true], replyHandler: nil) { error in
                    // Silently ignore - sendMessage fails if iPhone is unreachable
                }
                logger.info("Sent wake message to iPhone")
            }
        }
    }
}
