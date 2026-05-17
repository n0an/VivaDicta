// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import TestUtilities
import TranscriptionCore
import TranscriptionKit

/// Hand-rolled mock for ``TranscriptionEngine`` following the Bev pattern:
/// per-method `stub...` for return values, `...CallCount` for invocation
/// counts, and `last...` capture of the most recent arguments.
///
/// Use this from app-target tests to verify routing without touching real
/// network or local-model code.
public final class MockTranscriptionEngine: TranscriptionEngine, @unchecked Sendable {

    public init() {}

    // MARK: - transcribe

    public var stubTranscribeResult: Result<TranscriptionServiceResult, Error>?
    public private(set) var transcribeCallCount = 0
    public private(set) var lastTranscribeAudioURL: URL?
    public private(set) var lastTranscribeProvider: TranscriptionProvider?
    public private(set) var lastTranscribeProgressWasNonNil = false

    public func transcribe(
        audioURL: URL,
        using provider: TranscriptionProvider,
        progress: TranscriptionProgressHandler?
    ) async throws -> TranscriptionServiceResult {
        transcribeCallCount += 1
        lastTranscribeAudioURL = audioURL
        lastTranscribeProvider = provider
        lastTranscribeProgressWasNonNil = progress != nil
        return try stubTranscribeResult.evaluate()
    }

    // MARK: - preloadWhisperKitModel

    public private(set) var preloadWhisperKitModelCallCount = 0
    public private(set) var lastPreloadWhisperKitModelName: String?

    public func preloadWhisperKitModel(named modelName: String) async {
        preloadWhisperKitModelCallCount += 1
        lastPreloadWhisperKitModelName = modelName
    }
}
