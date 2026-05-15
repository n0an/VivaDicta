// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import LocalTranscription
import TestUtilities
import TranscriptionCore

/// Mock for the `WhisperKitTranscriptionService` shape - mirrors the
/// `transcribe(audioURL:modelName:displayName:options:)` signature so callers
/// can swap it in via a protocol or a generic wrapper.
public final class MockWhisperKitTranscriptionService: @unchecked Sendable {

    public init() {}

    public var stubTranscribeResponse: Result<TranscriptionServiceResult, Error>?
    public var didTranscribe: (() -> Void)?
    public private(set) var transcribeCallCount = 0
    public private(set) var capturedAudioURL: URL?
    public private(set) var capturedModelName: String?
    public private(set) var capturedOptions: WhisperKitTranscriptionService.Options?

    public func transcribe(
        audioURL: URL,
        modelName: String,
        displayName: String? = nil,
        options: WhisperKitTranscriptionService.Options
    ) async throws -> TranscriptionServiceResult {
        defer { didTranscribe?() }
        transcribeCallCount += 1
        capturedAudioURL = audioURL
        capturedModelName = modelName
        capturedOptions = options
        return try stubTranscribeResponse.evaluate()
    }

    public var preloadCallCount = 0
    public var capturedPreloadModelName: String?
    public func preloadModelIfNeeded(modelName: String) async {
        preloadCallCount += 1
        capturedPreloadModelName = modelName
    }

    public var unloadCallCount = 0
    public func unloadModel() async {
        unloadCallCount += 1
    }
}
