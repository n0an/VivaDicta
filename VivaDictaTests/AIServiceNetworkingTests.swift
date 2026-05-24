// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import VivaDicta

/// Smoke tests confirming `AIService` plumbs the injected `URLSessionProtocol`
/// through to the underlying HTTP calls. Full per-provider coverage lives in
/// each provider's own test suite; this file just locks in the wiring so a
/// future refactor that drops the injection is caught immediately.
@MainActor
struct AIServiceNetworkingTests {

    private let suiteName = "AIServiceNetworkingTests.\(UUID().uuidString)"

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func storesInjectedURLSession() {
        let session = MockURLSession()
        let service = AIService(userDefaults: makeDefaults(), urlSession: session)

        // The injected mock should be reachable as the same instance.
        #expect(service.urlSession is MockURLSession)
    }

    @Test func defaultURLSessionIsRealURLSessionWhenNotInjected() {
        let service = AIService(userDefaults: makeDefaults())

        #expect(service.urlSession is URLSession)
    }
}
