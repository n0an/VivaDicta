// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing

/// Swift Testing replacement for `XCTestExpectation`. Use when a test needs
/// to wait for an asynchronous callback before asserting state.
///
/// Unlike a naive `Task.sleep(timeout) + check` implementation, `wait()`
/// returns immediately once `fulfill()` has been called - either before
/// `wait()` (fast path) or during the wait via a continuation race with
/// the timeout. The full timeout is only paid in the failing case.
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

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    if isFulfilled {
                        cont.resume()
                    } else {
                        self.continuation = cont
                    }
                }
            }
            group.addTask { [timeout] in
                try? await Task.sleep(for: .seconds(timeout))
            }
            _ = await group.next()
            group.cancelAll()
        }

        try #require(isFulfilled)
    }
}
