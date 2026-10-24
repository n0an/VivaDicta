// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Analytics
import os

/// Production `AnalyticsService`. VivaDicta collects no usage analytics, and
/// this type sends exactly one thing.
///
/// When the keyboard is used inside a host app the app has no return URL for,
/// it POSTs `{"bundleId": "<host bundle ID>", "appVersion": "<app version>"}`
/// to ``endpoint``, so a return route for that app can be added in a later
/// release. Nothing else goes out: no device identifier, no IDFV, no account,
/// no transcript or note content.
///
/// Each bundle ID is sent at most once per install. An ID is only recorded as
/// reported after a 2xx response, so a failed send is retried the next time
/// that host comes up. Failures are logged and otherwise ignored.
///
/// Stateless apart from `UserDefaults` and a lock, and `Sendable`, so `track`
/// can be called from any context.
struct DefaultAnalyticsService: AnalyticsService {
    /// Shared production instance - one symbol to inject as the default and to
    /// grep for call sites.
    nonisolated static let live = DefaultAnalyticsService()

    /// Receives unrecognized keyboard host bundle IDs.
    nonisolated private static let endpoint = URL(string: "https://vivadicta.com/api/unrecognized-host")!

    /// `UserDefaults.standard` key holding the bundle IDs already delivered
    /// from this install.
    nonisolated private static let reportedIdsKey = "reportedUnrecognizedHostIds"

    nonisolated private static let logger = Logger(category: .analytics)

    /// Bundle IDs with a request in flight, so two keyboard sessions in quick
    /// succession don't send the same ID twice. Also serializes the
    /// read-modify-write of ``reportedIdsKey``.
    nonisolated private static let inFlight = OSAllocatedUnfairLock<Set<String>>(initialState: [])

    /// Ephemeral, so no cookies, cache or credentials are stored or sent.
    nonisolated private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    nonisolated func track(_ event: AnalyticsEvent) {
        switch event {
        case .unrecognizedHostApp(let bundleId):
            Self.reportUnrecognizedHost(bundleId)
        }
    }

    // MARK: - Unrecognized host

    nonisolated private static func reportUnrecognizedHost(_ bundleId: String) {
        // `hostId` arrives in a URL query, so anything could open the app with
        // an arbitrary string. Only send what looks like a bundle ID; the
        // server applies the same rule.
        guard isPlausibleBundleId(bundleId) else {
            Self.logger.logWarning("📊 Ignoring malformed host bundle ID")
            return
        }

        let shouldSend = Self.inFlight.withLock { pending in
            guard !pending.contains(bundleId), !Self.reportedIds().contains(bundleId) else { return false }
            pending.insert(bundleId)
            return true
        }
        guard shouldSend else { return }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let payload = ["bundleId": bundleId, "appVersion": appVersion]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            Self.logger.logError("📊 Could not encode unrecognized host report for \(bundleId)")
            Self.inFlight.withLock { _ = $0.remove(bundleId) }
            return
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        Self.session.dataTask(with: request) { _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let delivered = statusCode.map { (200..<300).contains($0) } ?? false

            Self.inFlight.withLock { pending in
                pending.remove(bundleId)
                if delivered {
                    UserDefaults.standard.set(Array(Self.reportedIds().union([bundleId])), forKey: Self.reportedIdsKey)
                }
            }

            if delivered {
                Self.logger.logInfo("📊 Reported unrecognized host \(bundleId)")
            } else if let error {
                Self.logger.logError("📊 Unrecognized host report failed for \(bundleId): \(error.localizedDescription)")
            } else {
                Self.logger.logError("📊 Unrecognized host report failed for \(bundleId): \(statusCode.map { "HTTP \($0)" } ?? "no response")")
            }
        }.resume()
    }

    /// Reverse-DNS shape (`com.example.notes`), at most 155 characters -
    /// matches the server-side check.
    nonisolated private static func isPlausibleBundleId(_ value: String) -> Bool {
        guard value.count <= 155 else { return false }
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        return labels.allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }

    /// Bundle IDs already delivered from this install.
    nonisolated private static func reportedIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.reportedIdsKey) ?? [])
    }
}
