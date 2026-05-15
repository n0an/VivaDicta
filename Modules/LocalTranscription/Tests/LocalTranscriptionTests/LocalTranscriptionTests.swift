// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import LocalTranscription
import LocalTranscriptionMocks
import TranscriptionCore
import TestUtilities

struct WhisperKitModelPathTests {

    @Test func directoryAppendsModelNameToRoot() {
        let url = WhisperKitModelPath.directory(forModelName: "openai_whisper-tiny")
        #expect(url.lastPathComponent == "openai_whisper-tiny")
        #expect(url.deletingLastPathComponent().lastPathComponent == "whisperkit-coreml")
    }

    @Test func rootHasExpectedHuggingFaceLayout() {
        let path = WhisperKitModelPath.root.path
        #expect(path.contains("/huggingface/models/argmaxinc/whisperkit-coreml"))
    }

    @Test func isDownloadedReturnsFalseForMissingModel() {
        let unique = "definitely-does-not-exist-\(UUID().uuidString)"
        #expect(WhisperKitModelPath.isDownloaded(modelName: unique) == false)
    }
}

struct WhisperKitOptionsTests {

    @Test func defaultsAreAutoLanguageVADEnabledNoDiarization() {
        let options = WhisperKitTranscriptionService.Options()
        #expect(options.language == "auto")
        #expect(options.isVADEnabled == true)
        #expect(options.isSpeakerDiarizationEnabled == false)
    }

    @Test func storesAllExplicitValues() {
        let options = WhisperKitTranscriptionService.Options(
            language: "fr",
            isVADEnabled: false,
            isSpeakerDiarizationEnabled: true
        )
        #expect(options.language == "fr")
        #expect(options.isVADEnabled == false)
        #expect(options.isSpeakerDiarizationEnabled == true)
    }
}

struct ParakeetOptionsTests {

    @Test func defaultsAreVADEnabledNoVocabulary() {
        let options = ParakeetTranscriptionService.Options()
        #expect(options.isVADEnabled == true)
        #expect(options.vocabulary.isEmpty)
    }

    @Test func storesVocabularyExplicitly() {
        let options = ParakeetTranscriptionService.Options(
            isVADEnabled: false,
            vocabulary: ["term-one", "term-two"]
        )
        #expect(options.isVADEnabled == false)
        #expect(options.vocabulary == ["term-one", "term-two"])
    }
}

struct MockWhisperKitTranscriptionServiceTests {

    @Test func transcribeReturnsStubbedValue() async throws {
        let mock = MockWhisperKitTranscriptionService()
        mock.stubTranscribeResponse = .success(.plain("hello"))
        let url = URL(fileURLWithPath: "/tmp/audio.wav")
        let result = try await mock.transcribe(
            audioURL: url,
            modelName: "openai_whisper-tiny",
            options: .init()
        )
        #expect(result.text == "hello")
        #expect(mock.transcribeCallCount == 1)
        #expect(mock.capturedAudioURL == url)
        #expect(mock.capturedModelName == "openai_whisper-tiny")
    }

    @Test func transcribePropagatesStubbedError() async {
        struct Boom: Error {}
        let mock = MockWhisperKitTranscriptionService()
        mock.stubTranscribeResponse = .failure(Boom())
        let url = URL(fileURLWithPath: "/tmp/audio.wav")
        await #expect(throws: Boom.self) {
            _ = try await mock.transcribe(
                audioURL: url,
                modelName: "openai_whisper-tiny",
                options: .init()
            )
        }
    }

    @Test func preloadAndUnloadAreCounted() async {
        let mock = MockWhisperKitTranscriptionService()
        await mock.preloadModelIfNeeded(modelName: "model-a")
        await mock.preloadModelIfNeeded(modelName: "model-b")
        await mock.unloadModel()

        #expect(mock.preloadCallCount == 2)
        #expect(mock.capturedPreloadModelName == "model-b")
        #expect(mock.unloadCallCount == 1)
    }
}
