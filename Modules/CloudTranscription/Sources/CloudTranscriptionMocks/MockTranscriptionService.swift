// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import CloudTranscription
import TranscriptionCore
import TestUtilities

/// Generic mock conforming to `TranscriptionService`. Serves every provider
/// (cloud + local) since the protocol surface is a single
/// `transcribe(audioURL:)` method. Tests that need to assert per-provider
/// routing create one `MockTranscriptionService` instance per route and
/// hand them to the engine's `ServiceFactory`.
///
/// ## Usage
///
/// ```swift
/// let sut = MockTranscriptionService()
/// sut.stubTranscribeResponse = .success(.plain("hello"))
/// let result = try await sut.transcribe(audioURL: testFile)
/// #expect(result.text == "hello")
/// #expect(sut.transcribeCallCount == 1)
/// ```
public final class MockTranscriptionService: TranscriptionService, @unchecked Sendable {

    public init() {}

    public var stubTranscribeResponse: Result<TranscriptionServiceResult, Error>?
    public var didTranscribe: (() -> Void)?
    public private(set) var transcribeCallCount = 0
    public private(set) var capturedAudioURL: URL?

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        defer { didTranscribe?() }
        transcribeCallCount += 1
        capturedAudioURL = audioURL
        return try stubTranscribeResponse.evaluate()
    }
}
