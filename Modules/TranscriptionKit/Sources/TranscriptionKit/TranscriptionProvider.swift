// Copyright © 2026 Anton Novoselov. All rights reserved.

import CloudTranscription
@preconcurrency import FluidAudio
import Foundation
import LocalTranscription
import TranscriptionCore

/// Describes which transcription backend to use for a single transcription
/// call. Each case carries the backend's specific config/options. Consumers
/// build a provider value and hand it to `TranscriptionEngine.transcribe`.
///
/// Cloud cases wrap the existing per-service `Config` types unchanged; local
/// cases name the model + options pair directly.
public enum TranscriptionProvider: Sendable {
    case openAI(OpenAITranscriptionService.Config)
    case gemini(GeminiTranscriptionService.Config)
    case groq(GroqTranscriptionService.Config)
    case elevenLabs(ElevenLabsTranscriptionService.Config)
    case cohere(CohereTranscriptionService.Config)
    case cartesia(CartesiaTranscriptionService.Config)
    case mistral(MistralTranscriptionService.Config)
    case deepgram(DeepgramTranscriptionService.Config)
    case soniox(SonioxTranscriptionService.Config)
    case gladia(GladiaTranscriptionService.Config)
    case speechmatics(SpeechmaticsTranscriptionService.Config)
    case custom(CustomTranscriptionService.Config)
    case whisperKit(
        modelName: String,
        displayName: String? = nil,
        options: WhisperKitTranscriptionService.Options
    )
    case parakeet(
        modelName: String,
        displayName: String? = nil,
        version: AsrModelVersion,
        options: ParakeetTranscriptionService.Options,
        progressHandler: TranscriptionProgressHandler? = nil
    )
}
