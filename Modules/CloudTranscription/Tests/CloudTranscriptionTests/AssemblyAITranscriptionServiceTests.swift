// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `AssemblyAITranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. AssemblyAI uses a three-stage **upload -> create ->
/// poll** job flow: the audio is uploaded to `/v2/upload`, a transcript job is
/// created via `/v2/transcript`, then the job is polled at
/// `/v2/transcript/{id}` until it reports `completed`. The `create` and `poll`
/// stages share `send(_:)`, so the suite drives them via
/// `MockNetworkService.stubSendResponses` (a FIFO queue).
///
/// Verifies the happy path, the endpoint/header/body shape of each stage, the
/// language / diarization / vocabulary branches, and the error paths (missing
/// key, upload failure, undecodable create, poll `error`). Every poll response
/// here resolves on the first iteration (`completed`/`error`), so no test waits
/// on the real poll interval.
@Suite(.tags(.networking))
struct AssemblyAITranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.assemblyai.com/v2/transcript")!,
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
        apiKey: String = "aai-test-key",
        modelName: String = "universal-3-5-pro",
        language: String = "auto",
        vocabulary: [String] = [],
        isSpeakerDiarizationEnabled: Bool = false
    ) -> AssemblyAITranscriptionService {
        AssemblyAITranscriptionService(
            config: .init(
                apiKey: apiKey,
                modelName: modelName,
                language: language,
                vocabulary: vocabulary,
                isSpeakerDiarizationEnabled: isSpeakerDiarizationEnabled
            ),
            networkService: networkService
        )
    }

    /// Stubs a successful upload -> create -> poll(completed) sequence.
    /// `transcript` is the transcript `text`; pass `utterances` to exercise the
    /// speaker-diarization branch.
    private func stubHappyFlow(
        on networkService: MockNetworkService,
        transcript: String = "hello world",
        utterances: [[String: Any]]? = nil
    ) throws {
        networkService.stubUploadResponse = .success((
            try jsonData(["upload_url": "https://cdn.assemblyai.com/upload/abc"]),
            httpResponse(200)
        ))
        var pollCompleted: [String: Any] = [
            "status": "completed",
            "text": transcript
        ]
        if let utterances {
            pollCompleted["utterances"] = utterances
        }
        networkService.stubSendResponses = [
            .success((try jsonData(["id": "transcript-1"]), httpResponse(200))),   // create
            .success((try jsonData(pollCompleted), httpResponse(200)))             // poll -> completed
        ]
    }

    // MARK: - Happy path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService, transcript: "assemblyai hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "assemblyai hello")
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
                ["text": "hi there", "speaker": "A"],
                ["text": "hello back", "speaker": "B"]
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
        #expect(upload.url?.absoluteString == "https://api.assemblyai.com/v2/upload")
        #expect(upload.httpMethod == "POST")
        #expect(create.url?.absoluteString == "https://api.assemblyai.com/v2/transcript")
        #expect(create.httpMethod == "POST")
        #expect(poll.url?.absoluteString == "https://api.assemblyai.com/v2/transcript/transcript-1")
        #expect(poll.httpMethod == "GET")
    }

    @Test func everyRequestSendsRawAuthorizationKey() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "aai-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        for request in networkService.capturedRequests {
            // AssemblyAI uses the raw key (no "Bearer" prefix).
            #expect(request.value(forHTTPHeaderField: "Authorization") == "aai-abc123")
        }
    }

    @Test func uploadSendsOctetStreamContentType() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(networkService.capturedRequests[0].value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test func createSendsJSONContentType() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(networkService.capturedRequests[1].value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: - Create body (audio_url / models / language / diarization / vocabulary)

    private func createBody(_ networkService: MockNetworkService) throws -> [String: Any] {
        let body = try #require(networkService.capturedRequests[1].httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func createBodyCarriesUploadedAudioUrlAndDefaultModels() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "universal-3-5-pro")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["audio_url"] as? String == "https://cdn.assemblyai.com/upload/abc")
        #expect(body["speech_models"] as? [String] == ["universal-3-5-pro", "universal-2"])
    }

    @Test func createBodyAppendsUniversal2FallbackForEmptyModelName() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "")

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["speech_models"] as? [String] == ["universal-3-5-pro", "universal-2"])
    }

    @Test func createBodyUsesSpecifiedModelWhenNotDefault() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "universal-2")

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["speech_models"] as? [String] == ["universal-2"])
    }

    @Test func createBodyEnablesLanguageDetectionWhenAuto() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "auto")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["language_detection"] as? Bool == true)
        #expect(body["language_code"] == nil)
    }

    @Test func createBodyPinsLanguageCodeWhenSpecified() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try createBody(networkService)
        #expect(body["language_code"] as? String == "fr")
        #expect(body["language_detection"] == nil)
    }

    @Test func createBodyEnablesSpeakerLabelsWhenDiarizationOn() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["speaker_labels"] as? Bool == true)
    }

    @Test func createBodyOmitsSpeakerLabelsWhenDiarizationOff() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: false)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["speaker_labels"] == nil)
    }

    @Test func createBodyIncludesVocabularyWhenProvided() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, vocabulary: ["SwiftUI", "Kubernetes"])

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["keyterms_prompt"] as? [String] == ["SwiftUI", "Kubernetes"])
    }

    @Test func createBodyOmitsVocabularyWhenEmpty() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, vocabulary: [])

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try createBody(networkService)["keyterms_prompt"] == nil)
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
            try jsonData(["upload_url": "https://cdn.assemblyai.com/upload/abc"]),
            httpResponse(200)
        ))
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
        #expect(networkService.sendCallCount == 1, "poll must not run when create can't be decoded")
    }

    @Test func pollStatusErrorThrowsApiRequestFailed() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((
            try jsonData(["upload_url": "https://cdn.assemblyai.com/upload/abc"]),
            httpResponse(200)
        ))
        networkService.stubSendResponses = [
            .success((try jsonData(["id": "transcript-1"]), httpResponse(200))),                          // create
            .success((try jsonData(["status": "error", "error": "unsupported language"]), httpResponse(200))) // poll -> error
        ]
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let error = try await #require(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        guard case let .apiRequestFailed(statusCode, message) = error else {
            Issue.record("expected apiRequestFailed, got \(error)")
            return
        }
        #expect(statusCode == -1)
        #expect(message.contains("unsupported language"))
    }
}
