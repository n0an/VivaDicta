//
//  WatchConnectivityServiceProtocol.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import Foundation

@MainActor
protocol WatchConnectivityServiceProtocol: AnyObject {
    var transferStatus: WatchTransferStatus { get }
    var pendingTransferCount: Int { get }
    var isCompanionReachable: Bool { get }
    func transferAudioFile(at url: URL, metadata: [String: Any]) -> Bool
}
