// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing

/// Swift Testing replacement for `XCTestExpectation`. Use when a test needs
/// to wait for an asynchronous callback before asserting state.
///
/// ## Usage
///
/// ```swift
/// let exp = SwiftExpectation(timeout: 0.5)
/// service.onSomethingHappened = { exp.fulfill() }
/// trigger()
/// try await exp.wait()
/// #expect(service.didThing)
/// ```
public final class SwiftExpectation: @unchecked Sendable {

    private let timeout: Double
    private var isFulfilled: Bool = false

    public init(timeout: Double = 1) {
        self.timeout = timeout
    }

    public func fulfill() {
        isFulfilled = true
    }

    /// Wait up to `timeout` seconds. Fails the test if the expectation was
    /// never fulfilled.
    public func wait() async throws {
        try await Task.sleep(for: .seconds(timeout))
        try #require(isFulfilled)
    }
}
