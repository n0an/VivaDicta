// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing

/// Thrown when a test calls a mocked method that requires a stub but no stub
/// was set. The Swift Testing port of Bev's `StubNotSetError`.
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
    /// 1. `nil` -> the stub has not been set; records a Swift Testing `Issue`
    ///    at the call site and throws `StubNotSetError`.
    /// 2. `.success(value)` -> returns `value`.
    /// 3. `.failure(error)` -> throws `error`.
    ///
    /// Uses standard built-in source-location macros so callers don't need to
    /// `import Testing` themselves.
    func evaluate<T>(
        _ message: @autoclosure () -> String = "Stub not set",
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) throws -> T where Wrapped == Result<T, Error> {
        switch self {
        case .some(let result):
            return try result.get()
        case .none:
            let detail = message()
            let location = SourceLocation(
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
            Issue.record(Comment(rawValue: detail), sourceLocation: location)
            throw StubNotSetError(detail)
        }
    }
}
