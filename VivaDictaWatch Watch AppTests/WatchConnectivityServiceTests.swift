//
//  WatchConnectivityServiceTests.swift
//  VivaDictaWatch Watch AppTests
//
//  Created by Anton Novoselov on 2026.04.04
//

import Foundation
import Testing
@testable import VivaDictaWatch_Watch_App

@MainActor
struct WatchConnectivityServiceTests {

    // MARK: - Test Helpers

    private func makeSUT() -> (WatchConnectivityService, UserDefaults) {
        let suiteName = "WatchConnectivityServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = WatchConnectivityService(defaults: defaults)
        return (sut, defaults)
    }

    // MARK: - Mode Parsing

    @Test func parseModes_fromValidApplicationContext() {
        let (sut, _) = makeSUT()
        let context: [String: Any] = [
            "modes": [
                ["id": "regular", "name": "Regular"],
                ["id": "summary", "name": "Summary"],
                ["id": "email", "name": "Email"]
            ]
        ]

        sut.parseModes(from: context)

        #expect(sut.availableModes.count == 3)
        #expect(sut.availableModes[0].id == "regular")
        #expect(sut.availableModes[1].name == "Summary")
        #expect(sut.availableModes[2].id == "email")
    }

    @Test func parseModes_emptyModesArray_setsEmptyList() {
        let (sut, _) = makeSUT()
        let context: [String: Any] = ["modes": [[String: String]]()]

        sut.parseModes(from: context)

        #expect(sut.availableModes.isEmpty)
    }

    @Test func parseModes_missingModesKey_keepsExistingModes() {
        let (sut, _) = makeSUT()
        // First set some modes
        sut.parseModes(from: ["modes": [["id": "regular", "name": "Regular"]]])
        #expect(sut.availableModes.count == 1)

        // Context without modes key should not clear existing modes
        sut.parseModes(from: ["someOtherKey": "value"])

        #expect(sut.availableModes.count == 1)
    }

    @Test func parseModes_malformedEntries_skipsInvalid() {
        let (sut, _) = makeSUT()
        let context: [String: Any] = [
            "modes": [
                ["id": "regular", "name": "Regular"],
                ["id": "broken"],                      // missing name
                ["name": "NoId"],                      // missing id
                ["id": "valid", "name": "Valid"]
            ]
        ]

        sut.parseModes(from: context)

        #expect(sut.availableModes.count == 2)
        #expect(sut.availableModes[0].id == "regular")
        #expect(sut.availableModes[1].id == "valid")
    }

    // MARK: - Mode Caching

    @Test func availableModes_cachesToUserDefaults() {
        let (sut, defaults) = makeSUT()
        let context: [String: Any] = [
            "modes": [
                ["id": "regular", "name": "Regular"],
                ["id": "summary", "name": "Summary"]
            ]
        ]

        sut.parseModes(from: context)

        let cached = defaults.array(forKey: "cachedWatchModes") as? [[String: String]]
        #expect(cached?.count == 2)
        #expect(cached?.first?["id"] == "regular")
    }

}
