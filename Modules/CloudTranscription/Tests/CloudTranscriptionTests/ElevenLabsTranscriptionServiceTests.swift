// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `ElevenLabsTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Verifies request shape (endpoint, `xi-api-key` header,
/// multipart body) and response handling, plus the word-level speaker
/// diarization grouping.
@Suite(.tags(.networking))
struct ElevenLabsTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func stubSuccess(on networkService: MockNetworkService, text: String) {
        let body = Data(#"{"text":"\#(text)"}"#.utf8)
        networkService.stubUploadResponse = .success((body, makeHTTPResponse(200)))
    }

    private func makeService(
        networkService: MockNetworkService,
        apiKey: String = "el-test-key",
        modelName: String = "scribe_v2",
        language: String = "auto",
        isSpeakerDiarizationEnabled: Bool = false
    ) -> ElevenLabsTranscriptionService {
        ElevenLabsTranscriptionService(
            config: .init(
                apiKey: apiKey,
                modelName: modelName,
                language: language,
                isSpeakerDiarizationEnabled: isSpeakerDiarizationEnabled
            ),
            networkService: networkService
        )
    }

    // MARK: - Success path

    @Test func successReturnsPlainText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "eleven hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "eleven hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsSpeechToTextEndpointWithApiKeyHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "el-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.elevenlabs.io/v1/speech-to-text")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "xi-api-key") == "el-abc123")
    }

    // MARK: - Diarization

    @Test func bodyOmitsDiarizeFieldByDefault() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"diarize\"") == false)
    }

    @Test func bodyIncludesDiarizeTrueWhenEnabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"diarize\"\\s*\\r\\n\\r\\ntrue", options: .regularExpression) != nil)
    }

    @Test func diarizationGroupsConsecutiveWordsBySpeaker() async throws {
        let networkService = MockNetworkService()
        // ElevenLabs interleaves `spacing` entries whose text is a literal space.
        let json = #"""
        {"text":"Hello there Hi","words":[
        {"text":"Hello","type":"word","speaker_id":"speaker_0"},
        {"text":" ","type":"spacing","speaker_id":"speaker_0"},
        {"text":"there","type":"word","speaker_id":"speaker_0"},
        {"text":" ","type":"spacing","speaker_id":"speaker_0"},
        {"text":"Hi","type":"word","speaker_id":"speaker_1"}
        ]}
        """#
        networkService.stubUploadResponse = .success((Data(json.utf8), makeHTTPResponse(200)))
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed)
        #expect(result.text == "Speaker A: Hello there\n\nSpeaker B: Hi")
    }

    @Test func diarizationEnabledButNoWordsFallsBackToPlainText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "no words here")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed == false)
        #expect(result.text == "no words here")
    }

    // MARK: - Response handling

    @Test func undecodableJSONOn200ThrowsNoTranscriptionReturned() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((Data("not json".utf8), makeHTTPResponse(200)))
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let error = try await #require(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        guard case .noTranscriptionReturned = error else {
            Issue.record("expected noTranscriptionReturned, got \(error)")
            return
        }
    }
}
