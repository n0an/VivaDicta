//
//  MockWatchConnectivityService.swift
//  VivaDictaWatch Watch AppTests
//
//  Created by Anton Novoselov on 2026.04.04
//

import Foundation
@testable import VivaDictaWatch_Watch_App

@Observable @MainActor
final class MockWatchConnectivityService: WatchConnectivityServiceProtocol {
    var transferStatus: WatchTransferStatus = .idle
    var pendingTransferCount: Int = 0
    var isCompanionReachable: Bool = true
    var availableModes: [WatchModeInfo] = []

    private(set) var transferredFiles: [(url: URL, metadata: [String: Any])] = []
    var shouldSucceedTransfer: Bool = true

    func transferAudioFile(at url: URL, metadata: [String: Any]) -> Bool {
        transferredFiles.append((url: url, metadata: metadata))
        if shouldSucceedTransfer {
            pendingTransferCount += 1
            transferStatus = .transferring(count: pendingTransferCount)
        }
        return shouldSucceedTransfer
    }
}
