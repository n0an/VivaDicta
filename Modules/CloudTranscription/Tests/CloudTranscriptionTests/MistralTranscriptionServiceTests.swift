// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `MistralTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Verifies request shape (URL, method, headers,
/// multipart body) and response handling (success, non-2xx, undecodable
/// JSON), plus the Mistral-specific diarization path.
///
/// Mirrors the structure of `OpenAITranscriptionServiceTests`. Retry-path
/// tests are intentionally skipped here - retry semantics belong on
/// `NetworkRetry`'s own tests.
@Suite(.tags(.networking))
struct MistralTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func stubSuccess(on networkService: MockNetworkService, text: String) {
        let body = Data(#"{"text":"\#(text)","language":"en","duration":0.5}"#.utf8)
        networkService.stubUploadResponse = .success((body, makeHTTPResponse(200)))
    }

    private func makeService(
        networkService: MockNetworkService,
        apiKey: String = "mst-test-key",
        modelName: String = "voxtral-mini-latest",
        language: String = "auto",
        isSpeakerDiarizationEnabled: Bool = false
    ) -> MistralTranscriptionService {
        MistralTranscriptionService(
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

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "mistral hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "mistral hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsMistralTranscriptionsEndpoint() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.mistral.ai/v1/audio/transcriptions")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "mst-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer mst-abc123")
    }

    @Test func requestSendsMultipartContentTypeWithBoundary() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let contentType = try #require(req.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary=Boundary-"))
    }

    @Test func bodyContainsModelField() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "voxtral-mini-latest")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        // Regex form (rather than separate `contains` checks) ensures the
        // value immediately follows its multipart field header, so a
        // misordered body can't pass by coincidence.
        #expect(bodyString.range(of: "name=\"model\"\\s*\\r\\n\\r\\nvoxtral-mini-latest", options: .regularExpression) != nil)
    }

    @Test func bodyIncludesLanguageFieldWhenNotAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nfr", options: .regularExpression) != nil)
    }

    @Test func bodyOmitsLanguageFieldWhenAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "auto")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"language\"") == false)
    }

    // MARK: - Diarization (Mistral-specific)

    @Test func bodyOmitsDiarizeFieldWhenDiarizationDisabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: false)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"diarize\"") == false)
        #expect(bodyString.contains("name=\"timestamp_granularities\"") == false)
    }

    @Test func bodyIncludesDiarizeFieldsWhenDiarizationEnabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"diarize\"\\s*\\r\\n\\r\\ntrue", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"timestamp_granularities\"\\s*\\r\\n\\r\\nsegment", options: .regularExpression) != nil)
    }

    @Test func bodyOmitsLanguageFieldWhenDiarizationEnabledEvenIfLanguageSet() async throws {
        // Mistral diarization requires automatic language detection, so an
        // explicit language is dropped when diarization is on.
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fr", isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"language\"") == false)
    }

    // MARK: - Validation / short-circuit

    @Test func missingAPIKeyThrowsBeforeMakingRequest() async throws {
        let networkService = MockNetworkService()
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "")

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        #expect(networkService.uploadCallCount == 0, "no network call should be made when API key is empty")
    }

    @Test func missingAudioFileThrowsAudioFileNotFound() async {
        let networkService = MockNetworkService()
        let audio = URL.temporaryDirectory.appending(path: "definitely-not-a-real-file-\(UUID()).wav")
        let sut = makeService(networkService: networkService)

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
    }

    // MARK: - Response handling

    @Test func nonSuccessStatusThrowsApiRequestFailed() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success((
            Data(#"{"error":"invalid key"}"#.utf8),
            makeHTTPResponse(401)
        ))
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let error = try await #require(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        guard case let .apiRequestFailed(statusCode, message) = error else {
            Issue.record("expected CloudTranscriptionError.apiRequestFailed, got \(error)")
            return
        }
        #expect(statusCode == 401)
        #expect(message.contains("invalid key"))
    }

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
