// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AudioRecording
import TestUtilities

/// Test double for `AudioFileService`. Reference type (despite the protocol
/// being value-friendly) so tests can mutate stub state and inspect call
/// counts without dealing with copy-on-write semantics. Use `@unchecked
/// Sendable` because the mutable state is intentionally test-only.
public final class MockAudioFileService: AudioFileService, @unchecked Sendable {

    public init() {}

    public var stubMove: Result<Void, Error>?
    public var stubRemove: Result<Void, Error>?
    public var stubFileSize: Result<Int64, Error>?
    public var stubDuration: Result<TimeInterval, Error>?
    public var stubDownsample: Result<Void, Error>?

    public private(set) var moveCallCount = 0
    public private(set) var removeCallCount = 0
    public private(set) var fileSizeCallCount = 0
    public private(set) var durationCallCount = 0
    public private(set) var downsampleCallCount = 0

    public private(set) var capturedMove: (source: URL, destination: URL)?
    public private(set) var capturedRemove: URL?
    public private(set) var capturedDownsample: (source: URL, destination: URL)?

    public func move(from source: URL, to destination: URL) throws {
        moveCallCount += 1
        capturedMove = (source, destination)
        try stubMove.evaluate()
    }

    public func remove(at url: URL) throws {
        removeCallCount += 1
        capturedRemove = url
        try stubRemove.evaluate()
    }

    public func fileSize(at url: URL) throws -> Int64 {
        fileSizeCallCount += 1
        return try stubFileSize.evaluate()
    }

    public func duration(of url: URL) async throws -> TimeInterval {
        durationCallCount += 1
        return try stubDuration.evaluate()
    }

    public func downsampleTo16kHzMono(from source: URL, to destination: URL) async throws {
        downsampleCallCount += 1
        capturedDownsample = (source, destination)
        try stubDownsample.evaluate()
    }
}
