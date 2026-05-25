// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing

/// Swift Testing replacement for `XCTestExpectation`. Use when a test needs
/// to wait for an asynchronous callback before asserting state.
///
/// Synchronization is provided by `@MainActor` isolation. All mutation of
/// `isFulfilled` happens on the main actor, so no locks or atomics are
/// needed. Callers from other actors must `await`, which routes the calls
/// through the main actor's serial executor.
///
/// `wait()` short-circuits if `fulfill()` was already called - which is
/// the common case when the trigger is synchronous (e.g. setting up an
/// `@Observable` observer, then mutating in the same actor before
/// awaiting). For truly asynchronous callbacks that may fulfill *during*
/// the wait, the full timeout is paid in the success path. We don't have
/// that pattern in the codebase today; add it back if a real caller needs
/// it.
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
@MainActor
public final class SwiftExpectation {

    private let timeout: Double
    private var isFulfilled = false

    public init(timeout: Double = 1) {
        self.timeout = timeout
    }

    public func fulfill() {
        isFulfilled = true
    }

    /// Wait up to `timeout` seconds. Fails the test if the expectation was
    /// never fulfilled. Returns immediately if `fulfill()` was already
    /// called before `wait()`.
    public func wait() async throws {
        if isFulfilled { return }
        try await Task.sleep(for: .seconds(timeout))
        try #require(isFulfilled)
    }
}
