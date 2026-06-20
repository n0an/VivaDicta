// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `SonioxTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Soniox uses a four-stage **upload -> create -> poll ->
/// fetch-transcript** job flow; `create`, `poll`, and `fetch` all share
/// `send(_:)`, so the suite drives them via `MockNetworkService.stubSendResponses`
/// (a FIFO queue). Every poll response resolves on the first iteration, so no
/// test waits on the real poll interval.
@Suite(.tags(.networking))
struct SonioxTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.soniox.com/v1/transcriptions")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func makeService(
        networkService: MockNetworkService,
        apiKey: String = "snx-test-key",
        modelName: String = "stt-async-preview",
        language: String = "auto",
        vocabulary: [String] = [],
        isSpeakerDiarizationEnabled: Bool = false,
        translationTargetLanguage: String = ""
    ) -> SonioxTranscriptionService {
        SonioxTranscriptionService(
            config: .init(
                apiKey: apiKey,
                modelName: modelName,
                language: language,
                vocabulary: vocabulary,
                isSpeakerDiarizationEnabled: isSpeakerDiarizationEnabled,
                translationTargetLanguage: translationTargetLanguage
            ),
            networkService: networkService
        )
    }

    /// Stubs upload -> create -> poll(completed) -> fetch(transcript).
    private func stubHappyFlow(
        on networkService: MockNetworkService,
        transcript: String = "hello world",
        tokens: [[String: Any]]? = nil
    ) throws {
        networkService.stubUploadResponse = .success((
            try jsonData(["id": "file-1"]),
            httpResponse(200)
        ))
        var transcriptResponse: [String: Any] = ["text": transcript]
        if let tokens {
            transcriptResponse["tokens"] = tokens
        }
        networkService.stubSendResponses = [
            .success((try jsonData(["id": "tr-1"]), httpResponse(200))),               // create
            .success((try jsonData(["status": "completed"]), httpResponse(200))),       // poll -> completed
            .success((try jsonData(transcriptResponse), httpResponse(200)))             // fetch transcript
        ]
    }

    // MARK: - Happy path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService, transcript: "soniox hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "soniox hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
        #expect(networkService.sendCallCount == 3) // create + poll + fetch
    }

    @Test func speakerDiarizationReturnsAttributedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(
            on: networkService,
            transcript: "ignored when tokens present",
            tokens: [
                ["text": "hi there", "speaker": "1"],
                ["text": " hello back", "speaker": "2"]
            ]
        )
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed == true)
        #expect(result.text.contains("hi there"))
        #expect(result.text.contains("hello back"))
    }

    // MARK: - Request shape

    @Test func requestSequenceTargetsFilesCreatePollFetchEndpoints() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(networkService.capturedRequests.count == 4)
        let r = networkService.capturedRequests
        #expect(r[0].url?.absoluteString == "https://api.soniox.com/v1/files")
        #expect(r[0].httpMethod == "POST")
        #expect(r[1].url?.absoluteString == "https://api.soniox.com/v1/transcriptions")
        #expect(r[1].httpMethod == "POST")
        #expect(r[2].url?.absoluteString == "https://api.soniox.com/v1/transcriptions/tr-1")
        #expect(r[2].httpMethod == "GET")
        #expect(r[3].url?.absoluteString == "https://api.soniox.com/v1/transcriptions/tr-1/transcript")
        #expect(r[3].httpMethod == "GET")
    }

    @Test func everyRequestSendsBearerAuthorization() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "snx-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        for request in networkService.capturedRequests {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer snx-abc123")
        }
    }

    // MARK: - Create body

    private func createBody(_ networkService: MockNetworkService) throws -> [String: Any] {
        let body = try #require(networkService.capturedRequests[1].httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func createBodyCarriesFileIdModelAndFlags() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "stt-async-preview", isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["file_id"] as? String == "file-1")
        #expect(body["model"] as? String == "stt-async-preview")
        #expect(body["enable_speaker_diarization"] as? Bool == true)
        #expect(body["enable_language_identification"] as? Bool == true)
    }

    @Test func createBodyIncludesLanguageHintsWhenSpecified() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["language_hints"] as? [String] == ["fr"])
        #expect(body["language_hints_strict"] as? Bool == true)
    }

    @Test func createBodyOmitsLanguageHintsWhenAuto() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "auto")

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["language_hints"] == nil)
    }

    @Test func createBodyIncludesVocabularyContextWhenProvided() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, vocabulary: ["SwiftUI", "Kubernetes"])

        _ = try await sut.transcribe(audioURL: audio)

        let context = try #require(try createBody(networkService)["context"] as? [String: Any])
        #expect(context["terms"] as? [String] == ["SwiftUI", "Kubernetes"])
    }

    // MARK: - Error paths

    @Test func missingAPIKeyThrowsBeforeAnyRequest() async throws {
        let networkService = MockNetworkService()
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "")

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        #expect(networkService.uploadCallCount == 0)
        #expect(networkService.sendCallCount == 0)
    }

    @Test func uploadStageNonSuccessStatusThrowsApiRequestFailed() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((
            Data(#"{"error":"bad key"}"#.utf8),
            httpResponse(401)
        ))
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let error = try await #require(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        guard case let .apiRequestFailed(statusCode, _) = error else {
            Issue.record("expected apiRequestFailed, got \(error)")
            return
        }
        #expect(statusCode == 401)
        #expect(networkService.sendCallCount == 0)
    }

    @Test func pollStatusFailedThrowsApiRequestFailed() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((try jsonData(["id": "file-1"]), httpResponse(200)))
        networkService.stubSendResponses = [
            .success((try jsonData(["id": "tr-1"]), httpResponse(200))),           // create
            .success((try jsonData(["status": "failed"]), httpResponse(200)))       // poll -> failed
        ]
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let error = try await #require(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        guard case let .apiRequestFailed(statusCode, _) = error else {
            Issue.record("expected apiRequestFailed, got \(error)")
            return
        }
        #expect(statusCode == 500)
    }

    @Test func undecodableCreateResponseThrowsNoTranscriptionReturned() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((try jsonData(["id": "file-1"]), httpResponse(200)))
        networkService.stubSendResponses = [
            .success((Data(#"{"unexpected":true}"#.utf8), httpResponse(200))) // create: no "id"
        ]
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
