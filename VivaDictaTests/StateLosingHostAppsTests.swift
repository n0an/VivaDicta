//
//  StateLosingHostAppsTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.09.12
//

import Testing
@testable import VivaDicta

struct StateLosingHostAppsTests {
    private let sut = VivaDictaApp.StateLosingHostApps.self

    @Test func declinesReturnURLForAListedHost() {
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.MobileSMS", isSkipEnabled: true))
    }

    @Test func keepsReturnURLForAListedHostWhenTheSettingIsOff() {
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.MobileSMS", isSkipEnabled: false) == false)
    }

    @Test func keepsReturnURLForAHostThatReturnsCorrectly() {
        // Notes and Mail resume where the user was, so they must keep the
        // automatic teleport even with the setting on.
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.mobilenotes", isSkipEnabled: true) == false)
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.mobilemail", isSkipEnabled: true) == false)
    }

    @Test func keepsReturnURLForAnUnknownHost() {
        #expect(sut.shouldDeclineReturnURL(hostId: "com.example.unknown", isSkipEnabled: true) == false)
    }

    @Test func everyEntryHasADisplayNameForTheSettingsList() {
        #expect(sut.displayNames.count == sut.entries.count)
        #expect(sut.displayNames.allSatisfy { !$0.isEmpty })
    }

    @Test func bundleIdsAreUnique() {
        #expect(sut.bundleIds.count == sut.entries.count)
    }
}
