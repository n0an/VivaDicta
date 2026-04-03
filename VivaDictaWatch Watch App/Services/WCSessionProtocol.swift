//
//  WCSessionProtocol.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import WatchConnectivity

@MainActor
protocol WatchSessionProtocol: AnyObject {
    var isReachable: Bool { get }
    var delegate: WCSessionDelegate? { get set }
    var activationState: WCSessionActivationState { get }
    var hasContentPending: Bool { get }
    var outstandingFileTransfers: [WCSessionFileTransfer] { get }
    func activate()
    @discardableResult
    func transferFile(_ file: URL, metadata: [String: Any]?) -> WCSessionFileTransfer
}

extension WCSession: WatchSessionProtocol {}
