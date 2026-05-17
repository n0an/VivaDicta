// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import TranscriptionCore

/// The transcription stack's entry-point abstraction.
///
/// Production code uses ``DefaultTranscriptionEngine``; tests can substitute
/// a `MockTranscriptionEngine` (from `TranscriptionKitMocks`) injected
/// through `any TranscriptionEngine`.
///
/// The protocol is intentionally `Sendable` and not `@MainActor`-isolated:
/// consumers on any actor (CLI tools, server contexts, view models on
/// other actors) can use it without being forced onto the main thread.
public protocol TranscriptionEngine: Sendable {
    /// Transcribe `audioURL` using the backend described by `provider`.
    ///
    /// - Parameter progress: Optional callback for streaming progress updates.
    ///   Currently only Parakeet emits progress events; other backends ignore
    ///   the handler.
    func transcribe(
        audioURL: URL,
        using provider: TranscriptionProvider,
        progress: TranscriptionProgressHandler?
    ) async throws -> TranscriptionServiceResult

    /// Preload a WhisperKit model in the engine's cached service. Best-effort;
    /// failures are absorbed (the underlying service logs them).
    func preloadWhisperKitModel(named modelName: String) async
}

extension DefaultTranscriptionEngine: TranscriptionEngine {}
