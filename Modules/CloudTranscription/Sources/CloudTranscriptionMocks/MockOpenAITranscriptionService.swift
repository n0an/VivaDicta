// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import CloudTranscription
import TranscriptionCore
import TestUtilities

/// Hand-rolled mock for the `transcribe(audioURL:)` shape used by cloud
/// transcription services. Stub the result via `stubTranscribeResponse`.
///
/// Conforms to `TranscriptionService` so it can be returned from a
/// `TranscriptionEngine.ServiceFactory` to test engine-level routing.
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
