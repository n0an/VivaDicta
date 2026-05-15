// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
import Foundation
@testable import CloudTranscription
import CloudTranscriptionMocks
import TranscriptionCore
import TestUtilities

struct URLAudioMIMETypeTests {

    @Test func wavDefault() {
        let url = URL(fileURLWithPath: "/tmp/audio.wav")
        #expect(url.audioMIMEType == "audio/wav")
    }

    @Test func m4aMapsToAudioMP4() {
        let url = URL(fileURLWithPath: "/tmp/audio.m4a")
        #expect(url.audioMIMEType == "audio/mp4")
    }

    @Test func mp3MapsToAudioMPEG() {
        let url = URL(fileURLWithPath: "/tmp/audio.mp3")
        #expect(url.audioMIMEType == "audio/mpeg")
    }

    @Test func unknownExtensionDefaultsToWav() {
        let url = URL(fileURLWithPath: "/tmp/audio.xyz")
        #expect(url.audioMIMEType == "audio/wav")
    }
}

struct OpenAIConfigTests {

    @Test func storesApiKeyModelAndLanguage() {
        let config = OpenAITranscriptionService.Config(
            apiKey: "sk-test",
            modelName: "whisper-1",
            language: "en"
        )
        #expect(config.apiKey == "sk-test")
        #expect(config.modelName == "whisper-1")
        #expect(config.language == "en")
    }

    @Test func defaultLanguageIsAuto() {
        let config = OpenAITranscriptionService.Config(
            apiKey: "sk-test",
            modelName: "whisper-1"
        )
        #expect(config.language == "auto")
    }
}

struct MockTranscriptionServiceTests {

    @Test func transcribeReturnsStubbedValue() async throws {
        let mock = MockTranscriptionService()
        mock.stubTranscribeResponse = .success(.plain("hello world"))
        let url = URL(fileURLWithPath: "/tmp/audio.wav")
        let result = try await mock.transcribe(audioURL: url)
        #expect(result.text == "hello world")
        #expect(mock.transcribeCallCount == 1)
        #expect(mock.capturedAudioURL == url)
    }

    @Test func transcribePropagatesStubbedError() async {
        struct Boom: Error {}
        let mock = MockTranscriptionService()
        mock.stubTranscribeResponse = .failure(Boom())
        let url = URL(fileURLWithPath: "/tmp/audio.wav")
        await #expect(throws: Boom.self) {
            _ = try await mock.transcribe(audioURL: url)
        }
    }

    @Test func transcribeWithoutStubThrowsStubNotSet() async {
        await withKnownIssue {
            let mock = MockTranscriptionService()
            let url = URL(fileURLWithPath: "/tmp/audio.wav")
            await #expect(throws: StubNotSetError.self) {
                _ = try await mock.transcribe(audioURL: url)
            }
        }
    }
}
