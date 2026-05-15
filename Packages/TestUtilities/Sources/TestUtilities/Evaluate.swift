//
//  Evaluate.swift
//  TestUtilities
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing

public struct StubNotSetError: Error, CustomStringConvertible {
    public let description = "Stub not set"
    public init() {}
}

public extension Optional {

    /// Evaluates a `Result`-typed stub from a mock.
    ///
    /// - `.none`: records a Swift Testing issue and throws `StubNotSetError` so the
    ///   test fails fast at the call site that forgot to configure a stub.
    /// - `.some(.success)`: returns the wrapped value.
    /// - `.some(.failure)`: rethrows the wrapped error.
    func evaluate<T>(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> T where Wrapped == Result<T, Error> {
        switch self {
        case .some(let result):
            return try result.get()
        case .none:
            Issue.record("Stub not set", sourceLocation: sourceLocation)
            throw StubNotSetError()
        }
    }
}
