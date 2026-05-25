// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import VivaDicta

/// Smoke tests confirming `AIService` plumbs the injected `NetworkService`
/// through to the underlying HTTP calls. Full per-provider coverage lives in
/// each provider's own test suite; this file just locks in the wiring so a
/// future refactor that drops the injection is caught immediately.
@Suite(.tags(.networking))
@MainActor
struct AIServiceNetworkingTests {

    private let suiteName = "AIServiceNetworkingTests.\(UUID().uuidString)"

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func storesInjectedNetworkService() {
        let networkService = MockNetworkService()
        let sut = AIService(userDefaults: makeDefaults(), networkService: networkService)

        #expect(sut.networkService is MockNetworkService)
    }

    @Test func defaultNetworkServiceIsDefaultNetworkServiceWhenNotInjected() {
        let sut = AIService(userDefaults: makeDefaults())

        #expect(sut.networkService is DefaultNetworkService)
    }
}
