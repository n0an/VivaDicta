// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Analytics

/// Records tracked events so tests can assert which analytics fired.
///
/// `@unchecked Sendable` with a lock because `track` is `nonisolated` and may be
/// called from any context (mirrors `MockNetworkService`).
public final class MockAnalyticsService: AnalyticsService, @unchecked Sendable {
    public init() {}
    private let lock = NSLock()
    private var _events: [AnalyticsEvent] = []

    public var trackedEvents: [AnalyticsEvent] { lock.withLock { _events } }
    public var trackedEventNames: [String] { lock.withLock { _events.map(\.name) } }

    public nonisolated func track(_ event: AnalyticsEvent) {
        lock.withLock { _events.append(event) }
    }
}
