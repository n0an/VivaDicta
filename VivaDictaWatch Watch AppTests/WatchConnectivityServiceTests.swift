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

    private func makeService() -> (WatchConnectivityService, UserDefaults) {
        let suiteName = "WatchConnectivityServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let service = WatchConnectivityService(defaults: defaults)
        return (service, defaults)
    }

    // MARK: - Mode Parsing

    @Test func parseModes_fromValidApplicationContext() {
        let (service, _) = makeService()
        let context: [String: Any] = [
            "modes": [
                ["id": "regular", "name": "Regular"],
                ["id": "summary", "name": "Summary"],
                ["id": "email", "name": "Email"]
            ]
        ]

        service.parseModes(from: context)

        #expect(service.availableModes.count == 3)
        #expect(service.availableModes[0].id == "regular")
        #expect(service.availableModes[1].name == "Summary")
        #expect(service.availableModes[2].id == "email")
    }

    @Test func parseModes_emptyModesArray_setsEmptyList() {
        let (service, _) = makeService()
        let context: [String: Any] = ["modes": [[String: String]]()]

        service.parseModes(from: context)

        #expect(service.availableModes.isEmpty)
    }

    @Test func parseModes_missingModesKey_keepsExistingModes() {
        let (service, _) = makeService()
        // First set some modes
        service.parseModes(from: ["modes": [["id": "regular", "name": "Regular"]]])
        #expect(service.availableModes.count == 1)

        // Context without modes key should not clear existing modes
        service.parseModes(from: ["someOtherKey": "value"])

        #expect(service.availableModes.count == 1)
    }

    @Test func parseModes_malformedEntries_skipsInvalid() {
        let (service, _) = makeService()
        let context: [String: Any] = [
            "modes": [
                ["id": "regular", "name": "Regular"],
                ["id": "broken"],                      // missing name
                ["name": "NoId"],                      // missing id
                ["id": "valid", "name": "Valid"]
            ]
        ]

        service.parseModes(from: context)

        #expect(service.availableModes.count == 2)
        #expect(service.availableModes[0].id == "regular")
        #expect(service.availableModes[1].id == "valid")
    }

    // MARK: - Mode Caching

    @Test func availableModes_cachesToUserDefaults() {
        let (service, defaults) = makeService()
        let context: [String: Any] = [
            "modes": [
                ["id": "regular", "name": "Regular"],
                ["id": "summary", "name": "Summary"]
            ]
        ]

        service.parseModes(from: context)

        let cached = defaults.array(forKey: "cachedWatchModes") as? [[String: String]]
        #expect(cached?.count == 2)
        #expect(cached?.first?["id"] == "regular")
    }

}
