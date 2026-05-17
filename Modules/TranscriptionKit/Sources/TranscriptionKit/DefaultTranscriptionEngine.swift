// Copyright © 2026 Anton Novoselov. All rights reserved.

import CloudTranscription
@preconcurrency import FluidAudio
import Foundation
import LocalTranscription
import TranscriptionCore

/// Production conformer of ``TranscriptionEngine`` and the unified entry
/// point to VivaDicta's transcription stack. Pick a `TranscriptionProvider`
/// describing where to transcribe; pass the audio URL; get text back.
///
/// Cloud providers are stateless - each call constructs a fresh service
/// instance from the provider's config. Local providers (WhisperKit,
/// Parakeet) are stateful - the engine caches a single instance of each so
/// loaded models survive across calls. Call `unloadLocalModels()` when you
/// want to free that memory.
///
/// ## Concurrency
///
/// `DefaultTranscriptionEngine` is an `actor`. Cache access (the WhisperKit /
/// Parakeet service instances it holds) is serialized by the actor; the
/// heavy work happens inside the awaited service calls, which are
/// non-isolated async functions and run off the actor on the global
/// executor.
///
/// The engine is deliberately not `@MainActor` so library consumers (CLI
/// tools, server contexts, view models on other actors) can use it without
/// being forced onto the main thread. Concurrent transcription requests
/// against the same local model from different tasks are not supported
/// (the underlying service holds a single loaded model).
public actor DefaultTranscriptionEngine {
    /// Maps a `TranscriptionProvider` to the concrete service that will
    /// transcribe the audio. Injected at init for tests; `nil` in production
    /// (the engine uses its built-in dispatch + local-service cache).
    public typealias ServiceFactory = @Sendable (
        TranscriptionProvider,
        TranscriptionProgressHandler?
    ) -> any TranscriptionService

    private var whisperKitService: WhisperKitTranscriptionService?
    private var parakeetService: ParakeetTranscriptionService?
    private let serviceFactory: ServiceFactory?

    /// Build an engine for production use. The default dispatch handles all
    /// backends and caches local services across calls.
    public init() {
        self.serviceFactory = nil
    }

    /// Build an engine that routes every `transcribe` call through the
    /// supplied factory instead of the built-in dispatch. Use this from tests
    /// to inject mocks of `TranscriptionService` and verify routing without
    /// touching real network/model code.
    public init(serviceFactory: @escaping ServiceFactory) {
        self.serviceFactory = serviceFactory
    }

    /// Transcribe `audioURL` using the backend described by `provider`.
    ///
    /// - Parameter progress: Optional callback for streaming progress updates.
    ///   Currently only Parakeet emits progress events; other backends ignore
    ///   the handler.
    public func transcribe(
        audioURL: URL,
        using provider: TranscriptionProvider,
        progress: TranscriptionProgressHandler? = nil
    ) async throws -> TranscriptionServiceResult {
        let service = serviceFactory?(provider, progress)
            ?? makeService(for: provider, progress: progress)
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
        // WhisperKit needs an explicit `unloadModel()` to release the
        // WhisperKit + SpeakerKit instances it holds. Parakeet's
        // `ParakeetTranscriptionService` releases its `AsrManager` after each
        // transcription in `cleanupAfterTranscription`, so dropping the
        // wrapper reference is sufficient.
        await whisperKitService?.unloadModel()
        whisperKitService = nil
        parakeetService = nil
    }

    // MARK: - Private cache

    /// Returns the engine's cached WhisperKit service, creating it lazily.
    /// Private so the cache is owned entirely by the actor.
    private func whisperKit() -> WhisperKitTranscriptionService {
        if let whisperKitService { return whisperKitService }
        let service = WhisperKitTranscriptionService()
        whisperKitService = service
        return service
    }

    /// Returns the engine's cached Parakeet service, creating it lazily.
    private func parakeet() -> ParakeetTranscriptionService {
        if let parakeetService { return parakeetService }
        let service = ParakeetTranscriptionService()
        parakeetService = service
        return service
    }

    // MARK: - Dispatch

    private func makeService(
        for provider: TranscriptionProvider,
        progress: TranscriptionProgressHandler?
    ) -> any TranscriptionService {
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
        case .xai(let config):
            return XaiTranscriptionService(config: config)
        case .custom(let config):
            return CustomTranscriptionService(config: config)
        case .whisperKit(let modelName, let displayName, let options):
            return whisperKit().operation(
                modelName: modelName,
                displayName: displayName,
                options: options
            )
        case .parakeet(let modelName, let displayName, let version, let options):
            return parakeet().operation(
                modelName: modelName,
                displayName: displayName,
                version: asrModelVersion(for: version),
                options: options,
                progressHandler: progress
            )
        }
    }

    private nonisolated func asrModelVersion(for version: ParakeetModelVersion) -> AsrModelVersion {
        switch version {
        case .v2: return .v2
        case .v3: return .v3
        }
    }
}
