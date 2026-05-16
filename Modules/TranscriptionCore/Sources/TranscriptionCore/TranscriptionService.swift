// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// The unified contract every transcription backend conforms to. Cloud
/// services (OpenAI, Groq, Gemini, ...) and local services (WhisperKit,
/// Parakeet) all expose audio-in / text-out via this single method, so a
/// higher-level orchestrator (e.g. `TranscriptionEngine`) can dispatch
/// uniformly.
///
/// Implementations are expected to be `Sendable` because callers will often
/// hold them across actor boundaries. Stateless impls (cloud HTTP wrappers)
/// can be value types; stateful impls (local services that cache a loaded
/// model) typically conform via `@unchecked Sendable` and rely on the
/// caller for serialization.
public protocol TranscriptionService: Sendable {
    func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult
}
