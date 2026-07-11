// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `GladiaTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Gladia uses a three-stage **upload -> create -> poll**
/// job flow, so the `create` and `poll` stages share `send(_:)` - the suite
/// drives them via `MockNetworkService.stubSendResponses` (a FIFO queue).
///
/// Verifies the happy path, the endpoint/header/body shape of each stage, the
/// `language_config` / vocabulary branches, speaker diarization, and the error
/// paths (missing key, upload failure, undecodable create, poll `error`). Every
/// poll response here resolves on the first iteration (`done`/`error`), so no
/// test waits on the real poll interval.
@Suite(.tags(.networking))
struct GladiaTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.gladia.io/v2/pre-recorded")!,
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
        apiKey: String = "gld-test-key",
        modelName: String = "solaria-1",
        language: String = "auto",
        vocabulary: [String] = [],
        isSpeakerDiarizationEnabled: Bool = false,
        translationTargetLanguage: String = ""
    ) -> GladiaTranscriptionService {
        GladiaTranscriptionService(
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

    /// Stubs a successful upload -> create -> poll(done) sequence.
    /// `transcript` is the `full_transcript`; pass `utterances` to exercise the
    /// speaker-diarization branch.
    private func stubHappyFlow(
        on networkService: MockNetworkService,
        transcript: String = "hello world",
        utterances: [[String: Any]]? = nil
    ) throws {
        networkService.stubUploadResponse = .success((
            try jsonData(["audio_url": "https://api.gladia.io/files/abc"]),
            httpResponse(200)
        ))
        var transcription: [String: Any] = ["full_transcript": transcript]
        if let utterances {
            transcription["utterances"] = utterances
        }
        let pollDone: [String: Any] = [
            "id": "job-1",
            "status": "done",
            "result": ["transcription": transcription]
        ]
        networkService.stubSendResponses = [
            .success((try jsonData(["id": "job-1"]), httpResponse(200))),       // create
            .success((try jsonData(pollDone), httpResponse(200)))               // poll -> done
        ]
    }

    // MARK: - Happy path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService, transcript: "gladia hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "gladia hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
        #expect(networkService.sendCallCount == 2) // create + one poll
    }

    @Test func speakerDiarizationReturnsAttributedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(
            on: networkService,
            transcript: "ignored when utterances present",
            utterances: [
                ["text": "hi there", "speaker": 0],
                ["text": "hello back", "speaker": 1]
            ]
        )
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed == true)
        #expect(result.text.contains("hi there"))
        #expect(result.text.contains("hello back"))
    }

    // MARK: - Request shape (sequence / endpoints / headers)

    @Test func requestSequenceTargetsUploadCreatePollEndpoints() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(networkService.capturedRequests.count == 3)
        let upload = networkService.capturedRequests[0]
        let create = networkService.capturedRequests[1]
        let poll = networkService.capturedRequests[2]
        #expect(upload.url?.absoluteString == "https://api.gladia.io/v2/upload")
        #expect(upload.httpMethod == "POST")
        #expect(create.url?.absoluteString == "https://api.gladia.io/v2/pre-recorded")
        #expect(create.httpMethod == "POST")
        #expect(poll.url?.absoluteString == "https://api.gladia.io/v2/pre-recorded/job-1")
        #expect(poll.httpMethod == "GET")
    }

    @Test func everyRequestSendsGladiaKeyHeader() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "gld-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        for request in networkService.capturedRequests {
            #expect(request.value(forHTTPHeaderField: "x-gladia-key") == "gld-abc123")
        }
    }

    @Test func uploadSendsMultipartContentTypeWithBoundary() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let contentType = try #require(networkService.capturedRequests[0].value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary=Boundary-"))
    }

    @Test func createSendsJSONContentType() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(networkService.capturedRequests[1].value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: - Create body (language_config / vocabulary / diarization)

    private func createBody(_ networkService: MockNetworkService) throws -> [String: Any] {
        let body = try #require(networkService.capturedRequests[1].httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func createBodyCarriesDefaultModel() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["model"] as? String == "solaria-1")
    }

    @Test func createBodyCarriesSolaria3WhenSelected() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "solaria-3", language: "de")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["model"] as? String == "solaria-3")
        let langConfig = try #require(body["language_config"] as? [String: Any])
        #expect(langConfig["languages"] as? [String] == ["de"])
        #expect(langConfig["code_switching"] as? Bool == false)
    }

    @Test func createBodyUsesCodeSwitchingWhenLanguageAuto() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "auto")

        _ = try await sut.transcribe(audioURL: audio)

        let langConfig = try #require(try createBody(networkService)["language_config"] as? [String: Any])
        #expect(langConfig["code_switching"] as? Bool == true)
        #expect((langConfig["languages"] as? [String])?.isEmpty == true)
    }

    @Test func createBodyPinsLanguageWhenSpecified() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let langConfig = try #require(try createBody(networkService)["language_config"] as? [String: Any])
        #expect(langConfig["languages"] as? [String] == ["fr"])
        #expect(langConfig["code_switching"] as? Bool == false)
    }

    @Test func createBodyEnablesDiarizationFlag() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["diarization"] as? Bool == true)
    }

    @Test func createBodyIncludesVocabularyWhenProvided() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, vocabulary: ["SwiftUI", "Kubernetes"])

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["custom_vocabulary"] as? Bool == true)
        let vocabConfig = try #require(body["custom_vocabulary_config"] as? [String: Any])
        #expect(vocabConfig["vocabulary"] as? [String] == ["SwiftUI", "Kubernetes"])
    }

    @Test func createBodyOmitsVocabularyWhenEmpty() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, vocabulary: [])

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["custom_vocabulary"] == nil)
    }

    // MARK: - Validation / error paths

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
        guard case let .apiRequestFailed(statusCode, message) = error else {
            Issue.record("expected apiRequestFailed, got \(error)")
            return
        }
        #expect(statusCode == 401)
        #expect(message.contains("bad key"))
        #expect(networkService.sendCallCount == 0, "create/poll must not run after upload fails")
    }

    @Test func undecodableCreateResponseThrowsNoTranscriptionReturned() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((
            try jsonData(["audio_url": "https://api.gladia.io/files/abc"]),
            httpResponse(200)
        ))
        networkService.stubSendResponses = [
            .success((Data(#"{"unexpected":true}"#.utf8), httpResponse(200))) // no "id"
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
        #expect(networkService.sendCallCount == 1, "poll must not run when create can't be decoded")
    }

    @Test func pollStatusErrorThrowsApiRequestFailed() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((
            try jsonData(["audio_url": "https://api.gladia.io/files/abc"]),
            httpResponse(200)
        ))
        networkService.stubSendResponses = [
            .success((try jsonData(["id": "job-1"]), httpResponse(200))),                  // create
            .success((try jsonData(["status": "error", "error_code": 42]), httpResponse(200))) // poll -> error
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
        #expect(statusCode == 42)
    }
}
