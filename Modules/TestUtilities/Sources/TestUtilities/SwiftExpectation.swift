// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing

/// Swift Testing replacement for `XCTestExpectation`. Use when a test needs
/// to wait for an asynchronous callback before asserting state.
///
/// Unlike a naive `Task.sleep(timeout) + check` implementation, `wait()`
/// returns immediately once `fulfill()` has been called - either before
/// `wait()` (fast path) or during the wait via a continuation resume. The
/// full timeout is only paid in the failing case.
///
/// Synchronization is provided by `@MainActor` isolation. All mutation of
/// `isFulfilled` and `continuation` happens on the main actor, so no
/// locks or atomics are needed. Callers from other actors must `await`,
/// which routes the calls through the main actor's serial executor.
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
    private var continuation: CheckedContinuation<Void, Never>?

    public init(timeout: Double = 1) {
        self.timeout = timeout
    }

    public func fulfill() {
        guard !isFulfilled else { return }
        isFulfilled = true
        continuation?.resume()
        continuation = nil
    }

    /// Wait up to `timeout` seconds. Fails the test if the expectation was
    /// never fulfilled. Returns immediately if `fulfill()` was already
    /// called before `wait()`.
    public func wait() async throws {
        if isFulfilled { return }

        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeout))
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            if isFulfilled {
                cont.resume()
                return
            }
            self.continuation = cont

            Task { @MainActor [weak self] in
                await timeoutTask.value
                guard let self, self.continuation != nil else { return }
                let pending = self.continuation
                self.continuation = nil
                pending?.resume()
            }
        }

        timeoutTask.cancel()
        try #require(isFulfilled)
    }
}
