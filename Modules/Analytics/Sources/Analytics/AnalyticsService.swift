//
//  AnalyticsService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.27
//

import Foundation

/// The complete list of what the app reports. VivaDicta collects no usage
/// analytics; the one exception is the bundle ID of a keyboard host app the
/// app does not know how to return to, so a return route for it can be added
/// in a later release.
///
/// Adding a case here means the app sends something new - update the privacy
/// manifest and the App Store privacy answers in the same change.
public enum AnalyticsEvent: Sendable, Equatable {

    /// The keyboard was used inside a host app VivaDicta has no return URL for.
    case unrecognizedHostApp(bundleId: String)
}

extension AnalyticsEvent {

    /// Stable identifier for the event, used in logs and test assertions.
    public nonisolated var name: String {
        switch self {
        case .unrecognizedHostApp: "unrecognized_host_app"
        }
    }
}

/// Reports events through one typed chokepoint, so nothing can be sent that is
/// not listed in ``AnalyticsEvent``. `track` is safe to call from any context.
///
/// Production wires `DefaultAnalyticsService`; tests wire
/// `MockAnalyticsService` to assert which events fired.
public protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}
