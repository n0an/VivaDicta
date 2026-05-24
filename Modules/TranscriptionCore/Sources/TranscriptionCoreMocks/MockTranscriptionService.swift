// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import TranscriptionCore

/// Backend-agnostic mock for `TranscriptionService`. Stub a fixed result
/// (success or error) and inspect what URL was transcribed.
///
/// Use this when the code under test only cares about the
/// `TranscriptionService` protocol (e.g. orchestration code in
/// `TranscriptionKit`), not which concrete backend is plugged in. When
/// the test needs backend-specific behavior, use the concrete mocks in
/// `CloudTranscriptionMocks` / `LocalTranscriptionMocks` instead.
public final class MockTranscriptionService: TranscriptionService, @unchecked Sendable {
    /// What `transcribe(audioURL:)` returns. When `nil` the mock falls
    /// back to a stub `TranscriptionServiceResult.plain("")`.
    public var stubTranscribeResult: Result<TranscriptionServiceResult, Error>?

    /// Every `audioURL` argument that has been passed to `transcribe`, in
    /// call order.
    public private(set) var transcribeCalls: [URL] = []

    /// Count of `transcribe` invocations. Equivalent to `transcribeCalls.count`
    /// but cheaper to assert against.
    public var transcribeCallCount: Int { transcribeCalls.count }

    public init() {}

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        transcribeCalls.append(audioURL)

        guard let stub = stubTranscribeResult else {
            return .plain("")
        }
        switch stub {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }
}
