// Copyright © 2026 Anton Novoselov. All rights reserved.

import CloudTranscription
import Foundation
import LocalTranscription
import TranscriptionCore

/// The unified entry point to VivaDicta's transcription stack. Pick a
/// `TranscriptionProvider` describing where to transcribe; pass the audio
/// URL; get text back.
///
/// Cloud providers are stateless - each call constructs a fresh service
/// instance from the provider's config. Local providers (WhisperKit,
/// Parakeet) are stateful - the engine caches a single instance of each so
/// loaded models survive across calls. Call `unloadLocalModels()` when you
/// want to free that memory.
public final class TranscriptionEngine: @unchecked Sendable {
    private var whisperKitService: WhisperKitTranscriptionService?
    private var parakeetService: ParakeetTranscriptionService?

    public init() {}

    /// Transcribe `audioURL` using the backend described by `provider`.
    public func transcribe(
        audioURL: URL,
        using provider: TranscriptionProvider
    ) async throws -> TranscriptionServiceResult {
        let service = makeService(for: provider)
        return try await service.transcribe(audioURL: audioURL)
    }

    /// Preload a WhisperKit model in the engine's cached service. Best-effort;
    /// failures are absorbed (the underlying service logs them).
    public func preloadWhisperKitModel(named modelName: String) async {
        await whisperKit().preloadModelIfNeeded(modelName: modelName)
    }

    /// Drop the cached WhisperKit/Parakeet services so their models leave
    /// memory. The engine will rebuild them on next use.
    public func unloadLocalModels() async {
        await whisperKitService?.unloadModel()
        whisperKitService = nil
        parakeetService = nil
    }

    /// The engine's cached WhisperKit service. Useful when callers need to
    /// query model state or reach API surface not covered by the protocol
    /// (e.g. observable durations for UI).
    public func whisperKit() -> WhisperKitTranscriptionService {
        if let whisperKitService { return whisperKitService }
        let service = WhisperKitTranscriptionService()
        whisperKitService = service
        return service
    }

    /// The engine's cached Parakeet service.
    public func parakeet() -> ParakeetTranscriptionService {
        if let parakeetService { return parakeetService }
        let service = ParakeetTranscriptionService()
        parakeetService = service
        return service
    }

    // MARK: - Dispatch

    private func makeService(for provider: TranscriptionProvider) -> any TranscriptionService {
        switch provider {
        case .openAI(let config):
            return OpenAITranscriptionService(config: config)
        case .gemini(let config):
            return GeminiTranscriptionService(config: config)
        case .groq(let config):
            return GroqTranscriptionService(config: config)
        case .elevenLabs(let config):
            return ElevenLabsTranscriptionService(config: config)
        case .cohere(let config):
            return CohereTranscriptionService(config: config)
        case .cartesia(let config):
            return CartesiaTranscriptionService(config: config)
        case .mistral(let config):
            return MistralTranscriptionService(config: config)
        case .deepgram(let config):
            return DeepgramTranscriptionService(config: config)
        case .soniox(let config):
            return SonioxTranscriptionService(config: config)
        case .gladia(let config):
            return GladiaTranscriptionService(config: config)
        case .speechmatics(let config):
            return SpeechmaticsTranscriptionService(config: config)
        case .custom(let config):
            return CustomTranscriptionService(config: config)
        case .whisperKit(let modelName, let displayName, let options):
            return whisperKit().operation(
                modelName: modelName,
                displayName: displayName,
                options: options
            )
        case .parakeet(let modelName, let displayName, let version, let options, let progressHandler):
            return parakeet().operation(
                modelName: modelName,
                displayName: displayName,
                version: version,
                options: options,
                progressHandler: progressHandler
            )
        }
    }
}
