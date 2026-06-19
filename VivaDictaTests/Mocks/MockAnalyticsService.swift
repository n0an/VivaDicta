// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
@testable import VivaDicta

/// Records tracked events so tests can assert which analytics fired.
///
/// `@unchecked Sendable` with a lock because `track` is `nonisolated` and may be
/// called from any context (mirrors `MockNetworkService`).
final class MockAnalyticsService: AnalyticsService, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AnalyticsEvent] = []

    var trackedEvents: [AnalyticsEvent] { lock.withLock { _events } }
    var trackedEventNames: [String] { lock.withLock { _events.map(\.name) } }

    nonisolated func track(_ event: AnalyticsEvent) {
        lock.withLock { _events.append(event) }
    }
}
