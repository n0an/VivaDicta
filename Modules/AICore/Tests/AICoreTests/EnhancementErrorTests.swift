import Testing
import Foundation
@testable import AICore

/// Characterization tests for the AI enhancement error type as it moves into
/// `AICore`. They lock the behavior (custom-message passthrough, structural
/// completeness) without over-asserting user-facing copy that may legitimately
/// change.
struct EnhancementErrorTests {

    private static let allCases: [EnhancementError] = [
        .notConfigured, .invalidResponse, .enhancementFailed,
        .networkError, .serverError, .rateLimitExceeded, .customError("x"),
    ]

    @Test func customErrorPassesItsMessageThroughBothDescriptions() {
        let sut = EnhancementError.customError("rate limited by upstream")
        #expect(sut.errorDescription == "rate limited by upstream")
        #expect(sut.failureReason == "An error occurred: rate limited by upstream")
    }

    @Test func everyCaseProducesNonEmptyDescriptions() {
        for sut in Self.allCases {
            #expect(sut.errorDescription?.isEmpty == false, "errorDescription for \(sut)")
            #expect(!sut.failureReason.isEmpty, "failureReason for \(sut)")
        }
    }
}
