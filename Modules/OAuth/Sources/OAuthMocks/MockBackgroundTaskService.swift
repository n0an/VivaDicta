// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import OAuth

/// Hand-rolled mock for `BackgroundTaskService`.
///
/// Returns an incrementing identifier from `beginBackgroundTask` and tracks
/// begin/end calls. Set `stubBeginResult` to `nil` to simulate the system
/// refusing to start a background task.
@MainActor
public final class MockBackgroundTaskService: BackgroundTaskService {

    public init() {}

    public private(set) var beginCallCount = 0
    public private(set) var endCallCount = 0
    public private(set) var capturedNames: [String] = []
    public private(set) var endedIdentifiers: [UInt] = []

    public var didBegin: (() -> Void)?
    public var didEnd: (() -> Void)?

    /// Optional override for the begin return value. When unset, the mock
    /// returns an incrementing identifier (1, 2, 3, ...).
    public var stubBeginResult: UInt?? = nil

    private var nextIdentifier: UInt = 1

    public func beginBackgroundTask(name: String, onExpiration: @escaping @Sendable () -> Void) -> UInt? {
        defer { didBegin?() }
        beginCallCount += 1
        capturedNames.append(name)
        if let override = stubBeginResult { return override }
        let identifier = nextIdentifier
        nextIdentifier += 1
        return identifier
    }

    public func endBackgroundTask(_ identifier: UInt) {
        defer { didEnd?() }
        endCallCount += 1
        endedIdentifiers.append(identifier)
    }
}
