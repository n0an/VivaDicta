// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Observation
import Testing

/// Wait for a property on an `@Observable` entity to change before asserting.
///
/// Uses Swift's `withObservationTracking` to register interest in one
/// property without spinning a busy loop. The wildcard read (`_ = ...`)
/// touches the property so the tracker arms, the `trigger` closure mutates
/// it, then we wait for `onChange` to fire. Fails the test if no change
/// arrives within `timeout`.
///
/// The single-closure form avoids the `async let` pattern (which trips
/// Swift 6 strict concurrency on non-`Sendable` observables) by keeping
/// observation setup, mutation, and waiting on the same actor.
///
/// ## Usage
///
/// ```swift
/// try await changes(to: \.recordingState, on: sut, timeout: 0.5) {
///     mockRecorder.fireDidFinishUnsuccessfully()
/// }
/// #expect(sut.recordingState == .idle)
/// ```
@MainActor
public func changes<T, U>(
    to keyPath: KeyPath<T, U>,
    on parent: T,
    timeout: Double = 1.0,
    trigger: () -> Void
) async throws {
    let exp = SwiftExpectation(timeout: timeout)
    withObservationTracking {
        _ = parent[keyPath: keyPath]
    } onChange: {
        exp.fulfill()
    }
    trigger()
    try await exp.wait()
}
