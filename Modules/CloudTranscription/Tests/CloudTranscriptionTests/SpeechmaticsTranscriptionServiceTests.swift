// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `SpeechmaticsTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Speechmatics uses an **upload(create-job) -> poll ->
/// fetch-transcript** flow. The job config travels inside the multipart upload
/// body (a `config` part), so config-shape assertions inspect
/// `MockNetworkService.capturedBody`; the `poll` and `fetch` stages share
/// `send(_:)` and are driven via `stubSendResponses`. Every poll response
/// resolves on the first iteration, so no test waits on the real poll interval.
@Suite(.tags(.networking))
struct SpeechmaticsTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://asr.api.speechmatics.com/v2/jobs")!,
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
        apiKey: String = "smx-test-key",
        modelName: String = "speechmatics-batch-v2",
        language: String = "auto",
        vocabulary: [String] = [],
        isSpeakerDiarizationEnabled: Bool = false,
        translationTargetLanguage: String = ""
    ) -> SpeechmaticsTranscriptionService {
        SpeechmaticsTranscriptionService(
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

    /// `results` are json-v2 transcript items; defaults to a two-word transcript.
    private func stubHappyFlow(
        on networkService: MockNetworkService,
        results: [[String: Any]] = [
            ["type": "word", "alternatives": [["content": "hello"]]],
            ["type": "word", "alternatives": [["content": "world"]]]
        ]
    ) throws {
        networkService.stubUploadResponse = .success((
            try jsonData(["id": "job-1"]),
            httpResponse(200)
        ))
        networkService.stubSendResponses = [
            .success((try jsonData(["job": ["id": "job-1", "status": "done"]]), httpResponse(200))), // poll -> done
            .success((try jsonData(["results": results]), httpResponse(200)))                        // fetch transcript
        ]
    }

    /// The createJob config JSON lives inside the multipart upload body.
    private func uploadBodyString(_ networkService: MockNetworkService) throws -> String {
        let body = try #require(networkService.capturedBody)
        return try #require(String(data: body, encoding: .utf8))
    }

    // MARK: - Happy path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "hello world")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
        #expect(networkService.sendCallCount == 2) // poll + fetch
    }

    @Test func punctuationAttachesToPreviousWordWithoutSpace() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService, results: [
            ["type": "word", "alternatives": [["content": "hello"]]],
            ["type": "punctuation", "attaches_to": "previous", "alternatives": [["content": "."]]]
        ])
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "hello.")
    }

    @Test func speakerDiarizationReturnsAttributedText() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService, results: [
            ["type": "word", "alternatives": [["content": "hi", "speaker": "S1"]]],
            ["type": "word", "alternatives": [["content": "bye", "speaker": "S2"]]]
        ])
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed == true)
        #expect(result.text.contains("hi"))
        #expect(result.text.contains("bye"))
    }

    // MARK: - Request shape

    @Test func requestSequenceTargetsJobsCreatePollFetchEndpoints() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(networkService.capturedRequests.count == 3)
        let r = networkService.capturedRequests
        #expect(r[0].url?.absoluteString == "https://asr.api.speechmatics.com/v2/jobs")
        #expect(r[0].httpMethod == "POST")
        #expect(r[1].url?.absoluteString == "https://asr.api.speechmatics.com/v2/jobs/job-1")
        #expect(r[1].httpMethod == "GET")
        #expect(r[2].url?.absoluteString == "https://asr.api.speechmatics.com/v2/jobs/job-1/transcript?format=json-v2")
        #expect(r[2].httpMethod == "GET")
    }

    @Test func everyRequestSendsBearerAuthorization() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "smx-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        for request in networkService.capturedRequests {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer smx-abc123")
        }
    }

    // MARK: - Config body (inside the multipart upload)

    @Test func configBodyMapsLegacyInternalNameToEnhancedModel() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try uploadBodyString(networkService)
        #expect(body.contains("\"model\":\"enhanced\""))
        #expect(!body.contains("operating_point"))
    }

    @Test func configBodyMelia1UsesMultiLanguageWithHint() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "melia-1", language: "de")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try uploadBodyString(networkService)
        #expect(body.contains("\"model\":\"melia-1\""))
        #expect(body.contains("\"language\":\"multi\""))
        #expect(body.contains("\"language_hints\":[\"de\"]"))
    }

    @Test func configBodyMelia1OmitsHintsWhenLanguageAuto() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "melia-1", language: "auto")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try uploadBodyString(networkService)
        #expect(body.contains("\"language\":\"multi\""))
        #expect(!body.contains("language_hints"))
    }

    @Test func configBodyMelia1DropsTranslationConfig() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "melia-1", translationTargetLanguage: "de")

        let result = try await sut.transcribe(audioURL: audio)

        let body = try uploadBodyString(networkService)
        #expect(!body.contains("translation_config"))
        #expect(result.text == "hello world")
    }

    @Test func configBodyMapsZhToCmn() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "zh")

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try uploadBodyString(networkService).contains("\"language\":\"cmn\""))
    }

    @Test func configBodyPassesNonMandarinLanguageThrough() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "de")

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try uploadBodyString(networkService).contains("\"language\":\"de\""))
    }

    @Test func configBodyEnablesSpeakerDiarization() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        #expect(try uploadBodyString(networkService).contains("\"diarization\":\"speaker\""))
    }

    @Test func configBodyIncludesAdditionalVocabWhenProvided() async throws {
        let networkService = MockNetworkService()
        try stubHappyFlow(on: networkService)
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, vocabulary: ["SwiftUI"])

        _ = try await sut.transcribe(audioURL: audio)

        let body = try uploadBodyString(networkService)
        #expect(body.contains("additional_vocab"))
        #expect(body.contains("\"content\":\"SwiftUI\""))
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

    @Test func createJobNonSuccessStatusThrowsApiRequestFailed() async throws {
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

    @Test func pollRejectedStatusThrowsApiRequestFailed() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((try jsonData(["id": "job-1"]), httpResponse(200)))
        networkService.stubSendResponses = [
            .success((try jsonData(["job": ["id": "job-1", "status": "rejected"]]), httpResponse(200)))
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
        #expect(statusCode == 422)
    }

    @Test func undecodableCreateResponseThrowsNoTranscriptionReturned() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((
            Data(#"{"unexpected":true}"#.utf8), // no "id"
            httpResponse(200)
        ))
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
