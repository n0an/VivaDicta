// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import TranscriptionCore
@testable import TranscriptionCoreMocks

@Suite("MockTranscriptionService")
struct MockTranscriptionServiceTests {

    private let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

    @Test func returnsEmptyResultWhenNoStubSet() async throws {
        let sut = MockTranscriptionService()

        let result = try await sut.transcribe(audioURL: audioURL)

        #expect(result.text == "")
        #expect(result.isSpeakerAttributed == false)
    }

    @Test func returnsStubbedSuccessResult() async throws {
        let sut = MockTranscriptionService()
        sut.stubTranscribeResult = .success(.plain("hello world"))

        let result = try await sut.transcribe(audioURL: audioURL)

        #expect(result.text == "hello world")
    }

    @Test func returnsStubbedSpeakerAttributedResult() async throws {
        let sut = MockTranscriptionService()
        sut.stubTranscribeResult = .success(.speakerAttributed("S1: hi\nS2: hey"))

        let result = try await sut.transcribe(audioURL: audioURL)

        #expect(result.text == "S1: hi\nS2: hey")
        #expect(result.isSpeakerAttributed)
    }

    @Test func throwsStubbedError() async {
        struct TestError: Error, Equatable {}
        let sut = MockTranscriptionService()
        sut.stubTranscribeResult = .failure(TestError())

        await #expect(throws: TestError.self) {
            _ = try await sut.transcribe(audioURL: self.audioURL)
        }
    }

    @Test func recordsAllTranscribeCallsInOrder() async throws {
        let sut = MockTranscriptionService()
        let url1 = URL(fileURLWithPath: "/tmp/a.m4a")
        let url2 = URL(fileURLWithPath: "/tmp/b.m4a")

        _ = try await sut.transcribe(audioURL: url1)
        _ = try await sut.transcribe(audioURL: url2)

        #expect(sut.transcribeCallCount == 2)
        #expect(sut.transcribeCalls == [url1, url2])
    }
}
