//
//  WebhookRetryPolicy.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation

/// What to do after one delivery attempt.
nonisolated enum WebhookAttemptDecision: Equatable, Sendable {
    case delivered(statusCode: Int)
    case retry(after: TimeInterval, reason: String)
    case giveUp(reason: String)
}

/// Retry and stop rules for webhook delivery.
///
/// - 2xx: delivered.
/// - Network errors, 408, 429 and 5xx: retry with backoff. `Retry-After`
///   (seconds or an HTTP date) is honored on 429 and 503.
/// - Any other status: stop and surface the failure.
/// - Items older than ``maxAge`` are dropped.
nonisolated enum WebhookRetryPolicy {
    /// Pending items older than this are dropped.
    static let maxAge: TimeInterval = 24 * 60 * 60

    /// Delay before attempt `n + 1` after `n` failed attempts.
    static let backoffSchedule: [TimeInterval] = [30, 2 * 60, 10 * 60, 30 * 60, 60 * 60]

    /// Upper bound for a server-provided `Retry-After`.
    static let maxRetryAfter: TimeInterval = 6 * 60 * 60

    static func backoff(afterFailedAttempts attempts: Int) -> TimeInterval {
        let index = min(max(attempts, 1), backoffSchedule.count) - 1
        return backoffSchedule[index]
    }

    static func isExpired(createdAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(createdAt) >= maxAge
    }

    /// - Parameters:
    ///   - statusCode: HTTP status, `nil` when the request failed before a response.
    ///   - retryAfter: raw `Retry-After` header value.
    ///   - errorCode: transport error, if any.
    ///   - errorDescription: human-readable transport error, if any.
    ///   - failedAttempts: attempts made so far, including this one.
    ///   - redirected: the response came from another URL (a redirect was
    ///     followed). Never counts as delivered, never retried.
    static func decide(
        statusCode: Int?,
        retryAfter: String?,
        errorCode: URLError.Code?,
        errorDescription: String?,
        failedAttempts: Int,
        redirected: Bool = false,
        now: Date
    ) -> WebhookAttemptDecision {
        let backoff = backoff(afterFailedAttempts: failedAttempts)

        if redirected {
            return .giveUp(reason: "Redirected to another URL. \(WebhookRedirects.notFollowedMessage)")
        }

        if let errorCode {
            let reason = errorDescription ?? "Network error (\(errorCode.rawValue))"
            if fatalErrorCodes.contains(errorCode) {
                return .giveUp(reason: reason)
            }
            return .retry(after: backoff, reason: reason)
        }

        guard let statusCode else {
            if let errorDescription {
                return .retry(after: backoff, reason: errorDescription)
            }
            return .retry(after: backoff, reason: "No HTTP response")
        }

        let reason = "HTTP \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized)"
        switch statusCode {
        case 200..<300:
            return .delivered(statusCode: statusCode)
        case 408:
            return .retry(after: backoff, reason: reason)
        case 429, 503:
            let delay = parseRetryAfter(retryAfter, now: now).map { min($0, maxRetryAfter) } ?? backoff
            return .retry(after: delay, reason: reason)
        case 500..<600:
            return .retry(after: backoff, reason: reason)
        case 300..<400:
            return .giveUp(reason: "\(reason). \(WebhookRedirects.notFollowedMessage)")
        default:
            return .giveUp(reason: reason)
        }
    }

    /// Parses `Retry-After` as delta-seconds or an HTTP date. Returns `nil` when absent or invalid.
    static func parseRetryAfter(_ value: String?, now: Date) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = Int(value) {
            return seconds >= 0 ? TimeInterval(seconds) : nil
        }
        guard let date = parseHTTPDate(value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    /// IMF-fixdate, e.g. "Wed, 21 Oct 2026 07:28:00 GMT".
    private static func parseHTTPDate(_ value: String) -> Date? {
        let style = Date.VerbatimFormatStyle(
            format: "\(weekday: .abbreviated), \(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) GMT",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: .gmt,
            calendar: Calendar(identifier: .gregorian)
        )
        return try? Date(value, strategy: style.parseStrategy)
    }

    /// Errors that will not fix themselves by retrying.
    private static let fatalErrorCodes: Set<URLError.Code> = [
        .badURL,
        .unsupportedURL,
        .appTransportSecurityRequiresSecureConnection,
        .fileDoesNotExist,
        .noPermissionsToReadFile,
    ]
}
