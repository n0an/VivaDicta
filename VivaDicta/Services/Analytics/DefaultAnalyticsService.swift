// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Analytics
import FirebaseAnalytics
import os

/// Firebase-backed `AnalyticsService`. Wraps `Analytics.logEvent`, merging in
/// device-condition parameters for events that opt in.
///
/// Stateless and `Sendable`, so `track` can be called from any context (matching
/// Firebase's thread-safety) - the same guarantee the previous static facade gave.
struct DefaultAnalyticsService: AnalyticsService {
    /// Shared production instance - one symbol to inject as the default and to
    /// grep when these call sites move to constructor injection / the module.
    nonisolated static let live = DefaultAnalyticsService()

    nonisolated private static let logger = Logger(category: .analytics)

    nonisolated func track(_ event: AnalyticsEvent) {
        let name = event.name

        var merged = event.parameters ?? [:]
        if event.attachesDeviceConditions {
            // Event-specific keys win on the (unexpected) collision.
            merged.merge(DeviceConditions.parameters) { current, _ in current }
        }
        let params: [String: Any]? = merged.isEmpty ? nil : merged

        Analytics.logEvent(name, parameters: params)

        if let params {
            Self.logger.logDebug("📊 \(name) \(params)")
        } else {
            Self.logger.logDebug("📊 \(name)")
        }
    }
}
