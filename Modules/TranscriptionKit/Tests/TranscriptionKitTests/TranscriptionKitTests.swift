// Copyright © 2026 Anton Novoselov. All rights reserved.

import CloudTranscription
import CloudTranscriptionMocks
import Foundation
import LocalTranscription
import LocalTranscriptionMocks
import Testing
import TranscriptionCore
@testable import TranscriptionKit

struct TranscriptionEngineTests {

    /// `unloadLocalModels()` is idempotent and safe to call on a freshly
    /// constructed engine. Smoke test that hits the actor methods without
    /// touching real models.
    @Test func unloadOnFreshEngineDoesNotThrow() async {
        let engine = TranscriptionEngine()
        await engine.unloadLocalModels()
        // Second call should also be a no-op.
        await engine.unloadLocalModels()
    }

    @Test func injectedFactoryReceivesProviderAndProgress() async throws {
        let mock = MockTranscriptionService()
        mock.stubTranscribeResponse = .success(.plain("hello"))

        let expectedAudio = URL(fileURLWithPath: "/tmp/test.wav")
        let received = ProviderCapture()

        let engine = TranscriptionEngine { provider, progress in
            received.set(provider: provider, progressIsNonNil: progress != nil)
            return mock
        }

        let result = try await engine.transcribe(
            audioURL: expectedAudio,
            using: .openAI(.init(apiKey: "test-key", modelName: "whisper-1"))
        )

        #expect(result.text == "hello")
        #expect(mock.transcribeCallCount == 1)
        #expect(mock.capturedAudioURL == expectedAudio)
        #expect(received.providerWasOpenAI)
        #expect(received.progressIsNonNil == false)
    }

    @Test func progressHandlerIsForwardedToFactory() async throws {
        let mock = MockTranscriptionService()
        mock.stubTranscribeResponse = .success(.plain("ok"))

        let capture = ProviderCapture()
        let engine = TranscriptionEngine { provider, progress in
            capture.set(provider: provider, progressIsNonNil: progress != nil)
            return mock
        }

        _ = try await engine.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/audio.wav"),
            using: .parakeet(
                modelName: "parakeet-v3",
                version: .v3,
                options: ParakeetTranscriptionService.Options(isVADEnabled: false, vocabulary: [])
            ),
            progress: { _ in /* no-op */ }
        )

        #expect(capture.progressIsNonNil == true)
    }

    @Test func injectedFactoryPropagatesError() async {
        struct StubError: Error, Equatable {}
        let mock = MockTranscriptionService()
        mock.stubTranscribeResponse = .failure(StubError())

        let engine = TranscriptionEngine { _, _ in mock }

        await #expect(throws: StubError.self) {
            _ = try await engine.transcribe(
                audioURL: URL(fileURLWithPath: "/tmp/a.wav"),
                using: .openAI(.init(apiKey: "k", modelName: "whisper-1"))
            )
        }
        #expect(mock.transcribeCallCount == 1)
    }

    @Test func whisperKitProviderCanBeRoutedToInjectedMock() async throws {
        let mock = MockWhisperKitTranscriptionService()
        mock.stubTranscribeResponse = .success(.plain("whisper output"))

        let engine = TranscriptionEngine { _, _ in mock }

        let result = try await engine.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/wk.wav"),
            using: .whisperKit(
                modelName: "openai_whisper-tiny",
                options: WhisperKitTranscriptionService.Options(
                    language: "auto",
                    isVADEnabled: false,
                    isSpeakerDiarizationEnabled: false
                )
            )
        )

        #expect(result.text == "whisper output")
        #expect(mock.transcribeCallCount == 1)
    }
}

/// Mutable capture buffer used by the tests above. Wraps a few values that
/// the `@Sendable` factory closure needs to write back to the test scope -
/// we can't capture `var` locals from a `@Sendable` closure, so we capture
/// this reference instead.
private final class ProviderCapture: @unchecked Sendable {
    private(set) var providerWasOpenAI = false
    private(set) var progressIsNonNil = false

    func set(provider: TranscriptionProvider, progressIsNonNil: Bool) {
        if case .openAI = provider { providerWasOpenAI = true }
        self.progressIsNonNil = progressIsNonNil
    }
}
