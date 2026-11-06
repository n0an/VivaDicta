//
//  WebhookRetryPolicyTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import Testing
@testable import VivaDicta

struct WebhookRetryPolicyTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func decide(status: Int?, retryAfter: String? = nil, error: URLError.Code? = nil, attempts: Int = 1) -> WebhookAttemptDecision {
        WebhookRetryPolicy.decide(
            statusCode: status,
            retryAfter: retryAfter,
            errorCode: error,
            errorDescription: error.map { "error \($0.rawValue)" },
            failedAttempts: attempts,
            now: now
        )
    }

    @Test(arguments: [200, 201, 202, 204, 299])
    func success_isAny2xx(status: Int) {
        #expect(decide(status: status) == .delivered(statusCode: status))
    }

    @Test(arguments: [408, 429, 500, 502, 503, 504, 599])
    func retryableStatuses_retry(status: Int) {
        guard case .retry = decide(status: status) else {
            Issue.record("Expected a retry for HTTP \(status)")
            return
        }
    }

    @Test(arguments: [301, 400, 401, 403, 404, 410, 413, 422])
    func otherStatuses_stop(status: Int) {
        guard case .giveUp(let reason) = decide(status: status) else {
            Issue.record("Expected to stop for HTTP \(status)")
            return
        }
        #expect(reason.hasPrefix("HTTP \(status)"))
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .timedOut, .cannotConnectToHost, .networkConnectionLost, .cannotFindHost])
    func networkErrors_retry(code: URLError.Code) {
        guard case .retry = decide(status: nil, error: code) else {
            Issue.record("Expected a retry for \(code)")
            return
        }
    }

    @Test(arguments: [URLError.Code.badURL, .unsupportedURL, .fileDoesNotExist])
    func unrecoverableErrors_stop(code: URLError.Code) {
        guard case .giveUp = decide(status: nil, error: code) else {
            Issue.record("Expected to stop for \(code)")
            return
        }
    }

    @Test func retryAfterSeconds_isHonoredOn429() {
        guard case .retry(let delay, _) = decide(status: 429, retryAfter: "120") else {
            Issue.record("Expected a retry")
            return
        }
        #expect(delay == 120)
    }

    @Test func retryAfterHTTPDate_isHonored() {
        // `now` is 2027-01-15T08:00:00Z; the header asks for five minutes later.
        guard case .retry(let delay, _) = decide(status: 503, retryAfter: "Fri, 15 Jan 2027 08:05:00 GMT") else {
            Issue.record("Expected a retry")
            return
        }
        #expect(delay == 300)
    }

    @Test func retryAfter_isCapped() {
        guard case .retry(let delay, _) = decide(status: 429, retryAfter: "999999") else {
            Issue.record("Expected a retry")
            return
        }
        #expect(delay == WebhookRetryPolicy.maxRetryAfter)
    }

    @Test func invalidRetryAfter_fallsBackToBackoff() {
        guard case .retry(let delay, _) = decide(status: 429, retryAfter: "soon", attempts: 2) else {
            Issue.record("Expected a retry")
            return
        }
        #expect(delay == WebhookRetryPolicy.backoff(afterFailedAttempts: 2))
    }

    @Test func backoff_growsAndCaps() {
        let delays = (1...8).map { WebhookRetryPolicy.backoff(afterFailedAttempts: $0) }
        #expect(delays == [30, 120, 600, 1800, 3600, 3600, 3600, 3600])
    }

    @Test(arguments: [301, 302, 303, 307, 308])
    func redirectStatuses_stopWithAHint(status: Int) {
        guard case .giveUp(let reason) = decide(status: status) else {
            Issue.record("Expected to stop for HTTP \(status)")
            return
        }
        #expect(reason.hasPrefix("HTTP \(status)"))
        #expect(reason.contains(WebhookRedirects.notFollowedMessage))
    }

    @Test func followedRedirect_isNeverDelivered() {
        let decision = WebhookRetryPolicy.decide(
            statusCode: 200, retryAfter: nil, errorCode: nil, errorDescription: nil,
            failedAttempts: 1, redirected: true, now: now
        )
        guard case .giveUp(let reason) = decision else {
            Issue.record("Expected to stop, got \(decision)")
            return
        }
        #expect(reason.hasPrefix("Redirected to another URL"))
    }

    @Test func expiry_afterMaxAge() {
        #expect(!WebhookRetryPolicy.isExpired(createdAt: now, now: now.addingTimeInterval(23 * 3600)))
        #expect(WebhookRetryPolicy.isExpired(createdAt: now, now: now.addingTimeInterval(24 * 3600)))
    }
}

struct WebhookRedirectsTests {

    private func same(_ lhs: String, _ rhs: String) -> Bool {
        WebhookRedirects.isSameEndpoint(URL(string: lhs)!, URL(string: rhs)!)
    }

    @Test func sameEndpoint_toleratesCanonicalization() {
        #expect(same("https://example.com/hooks/a?x=1", "https://example.com/hooks/a?x=1"))
        #expect(same("https://Example.COM/hooks/a", "https://example.com/hooks/a"))
        #expect(same("https://example.com", "https://example.com/"))
        #expect(same("https://example.com/hooks/a", "https://example.com:443/hooks/a"))
    }

    @Test func otherEndpoint_isARedirect() {
        #expect(!same("https://example.com/hooks/a", "https://example.org/hooks/a"))
        #expect(!same("https://example.com/hooks/a", "http://example.com/hooks/a"))
        #expect(!same("https://example.com/hooks/a", "https://example.com:8443/hooks/a"))
        #expect(!same("https://example.com/hooks/a", "https://example.com/hooks/b"))
        #expect(!same("https://example.com/hooks/a?x=1", "https://example.com/hooks/a?x=2"))
    }
}
