// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `OpenAITranscriptionService` end-to-end with a stubbed
/// `MockNetworkService` (`URLSessionProtocol` conformer from `NetworkingMocks`).
/// Verifies request shape (URL, method, headers, multipart body) and
/// response handling (success, non-2xx, undecodable JSON).
///
/// Retry-path tests are intentionally skipped here - retry semantics belong
/// on `NetworkRetry`'s own tests.
///
/// Each test creates a fresh `MockNetworkService`, so there's no shared mutable
/// state and the suite is safe to run in parallel with other suites.
@Suite(.tags(.networking))
struct OpenAITranscriptionServiceTests {

    // MARK: - Test Helpers

    /// Writes a small payload to a unique temp URL and returns it. The bytes
    /// don't need to be valid audio - `OpenAITranscriptionService` just
    /// forwards them in the multipart body.
    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!,
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
        apiKey: String = "sk-test-key",
        modelName: String = "whisper-1",
        language: String = "auto"
    ) -> OpenAITranscriptionService {
        OpenAITranscriptionService(
            config: .init(apiKey: apiKey, modelName: modelName, language: language),
            networkService: networkService
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "hello world")
        let audio = try makeAudioFile()

        let sut = makeService(networkService: networkService)
        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "hello world")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsOpenAITranscriptionsEndpoint() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(networkService: networkService)
        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(networkService: networkService, apiKey: "sk-abc123")
        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-abc123")
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

    @Test func bodyContainsModelAndResponseFormatFields() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(networkService: networkService, modelName: "whisper-1")
        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        // Regex form (rather than separate `contains` checks) ensures each
        // value immediately follows its multipart field header, so a
        // misordered body can't pass by coincidence.
        #expect(bodyString.range(of: "name=\"model\"\\s*\\r\\n\\r\\nwhisper-1", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"response_format\"\\s*\\r\\n\\r\\njson", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"temperature\"\\s*\\r\\n\\r\\n0", options: .regularExpression) != nil)
    }

    @Test func bodyIncludesLanguageFieldWhenNotAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(networkService: networkService, language: "en")
        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nen", options: .regularExpression) != nil)
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
        // 401 is not retried (only 429 + 5xx are), so this throws immediately.
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
