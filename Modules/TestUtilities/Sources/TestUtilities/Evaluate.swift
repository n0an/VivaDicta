// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing

/// Thrown by mocks for test-infrastructure failures - either a stub the
/// test forgot to set, or a stub that exists but can't satisfy the call
/// (mismatched type, fundamentally unstubbable method). Carries a
/// message so the test report points at the specific mock + method.
///
/// Both the `.evaluate()` helper below and individual mocks
/// (`MockNetworkService`, `MockURLSession`) throw this directly so every
/// test-infra failure surfaces with a consistent error type.
public struct StubNotSetError: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String = "Stub not set") {
        self.description = description
    }
}

public extension Optional {
    /// Evaluate stubs in mock implementations of throwing dependencies.
    ///
    /// Stubs should be of type `Result<T, Error>?`. The optional is evaluated
    /// in 1 of 3 ways:
    /// 1. `nil` -> records a Swift Testing issue and throws `StubNotSetError`.
    /// 2. `.success(value)` -> returns `value`.
    /// 3. `.failure(error)` -> throws `error`.
    func evaluate<T>() throws -> T where Wrapped == Result<T, Error> {
        guard let result = self else {
            Issue.record("Stub not set")
            throw StubNotSetError()
        }
        return try result.get()
    }
}
