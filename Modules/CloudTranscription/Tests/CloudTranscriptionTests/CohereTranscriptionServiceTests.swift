// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `CohereTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Verifies request shape (URL, method, headers,
/// multipart body) and response handling (success, non-2xx, undecodable JSON).
///
/// Mirrors the structure of `OpenAITranscriptionServiceTests`. Unlike OpenAI/Groq,
/// Cohere always sends a `language` field (the caller normalizes "auto" to a
/// supported default before constructing the config), so there's no
/// omit-language path to test here. Retry-path tests are intentionally skipped -
/// retry semantics belong on `NetworkRetry`'s own tests.
@Suite(.tags(.networking))
struct CohereTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.cohere.com/v2/audio/transcriptions")!,
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
        apiKey: String = "co-test-key",
        modelName: String = "diarize-v1",
        language: String = "en"
    ) -> CohereTranscriptionService {
        CohereTranscriptionService(
            config: .init(apiKey: apiKey, modelName: modelName, language: language),
            networkService: networkService
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "cohere hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "cohere hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsCohereTranscriptionsEndpoint() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.cohere.com/v2/audio/transcriptions")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "co-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer co-abc123")
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

    @Test func bodyContainsModelLanguageAndTemperatureFields() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "diarize-v1", language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        // Regex form (rather than separate `contains` checks) ensures each
        // value immediately follows its multipart field header, so a
        // misordered body can't pass by coincidence.
        #expect(bodyString.range(of: "name=\"model\"\\s*\\r\\n\\r\\ndiarize-v1", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nfr", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"temperature\"\\s*\\r\\n\\r\\n0", options: .regularExpression) != nil)
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
