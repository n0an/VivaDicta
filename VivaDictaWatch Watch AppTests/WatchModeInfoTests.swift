//
//  WatchModeInfoTests.swift
//  VivaDictaWatch Watch AppTests
//
//  Created by Anton Novoselov on 2026.04.04
//

import Testing
@testable import VivaDictaWatch_Watch_App

struct WatchModeInfoTests {

    @Test func init_setsProperties() {
        let mode = WatchModeInfo(id: "regular", name: "Regular")

        #expect(mode.id == "regular")
        #expect(mode.name == "Regular")
    }

    @Test func identifiable_usesIdProperty() {
        let mode = WatchModeInfo(id: "summary", name: "Summary")

        #expect(mode.id == "summary")
    }

    @Test func equality_sameValues() {
        let a = WatchModeInfo(id: "email", name: "Email")
        let b = WatchModeInfo(id: "email", name: "Email")

        #expect(a == b)
    }

    @Test func inequality_differentId() {
        let a = WatchModeInfo(id: "email", name: "Email")
        let b = WatchModeInfo(id: "summary", name: "Email")

        #expect(a != b)
    }

    @Test func inequality_differentName() {
        let a = WatchModeInfo(id: "email", name: "Email")
        let b = WatchModeInfo(id: "email", name: "Professional")

        #expect(a != b)
    }
}
