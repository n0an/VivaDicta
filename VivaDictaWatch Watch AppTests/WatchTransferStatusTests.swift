//
//  WatchTransferStatusTests.swift
//  VivaDictaWatch Watch AppTests
//
//  Created by Anton Novoselov on 2026.04.04
//

import Testing
@testable import VivaDictaWatch_Watch_App

struct WatchTransferStatusTests {

    @Test func equality_sameIdle() {
        #expect(WatchTransferStatus.idle == WatchTransferStatus.idle)
    }

    @Test func equality_sameTransferringCount() {
        #expect(WatchTransferStatus.transferring(count: 3) == WatchTransferStatus.transferring(count: 3))
    }

    @Test func inequality_differentTransferringCount() {
        #expect(WatchTransferStatus.transferring(count: 1) != WatchTransferStatus.transferring(count: 2))
    }

    @Test func equality_sameAllUploaded() {
        #expect(WatchTransferStatus.allUploaded == WatchTransferStatus.allUploaded)
    }

    @Test func equality_sameError() {
        #expect(WatchTransferStatus.error("fail") == WatchTransferStatus.error("fail"))
    }

    @Test func inequality_differentError() {
        #expect(WatchTransferStatus.error("a") != WatchTransferStatus.error("b"))
    }

    @Test func inequality_differentCases() {
        #expect(WatchTransferStatus.idle != WatchTransferStatus.allUploaded)
        #expect(WatchTransferStatus.idle != WatchTransferStatus.transferring(count: 1))
        #expect(WatchTransferStatus.allUploaded != WatchTransferStatus.error("x"))
    }
}
