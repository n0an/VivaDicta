// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `CustomTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Verifies request shape (URL, method, headers, and
/// both body formats - multipart and JSON/base64) and response handling
/// (success, non-2xx, undecodable JSON).
///
/// Unlike the fixed-provider services, this service builds its endpoint from
/// `config.apiEndpoint`, so the endpoint assertions match whatever base URL
/// the test config supplies. The API key is optional - the service simply
/// omits the `Authorization` header when no key is present, so there is no
/// "missing API key throws" short-circuit to cover here.
///
/// Mirrors the structure of `OpenAITranscriptionServiceTests`. Retry-path
/// tests are intentionally skipped here - retry semantics belong on
/// `NetworkRetry`'s own tests.
@Suite(.tags(.networking))
struct CustomTranscriptionServiceTests {

    // MARK: - Test Helpers

    private static let endpoint = "https://example.com/v1/audio/transcriptions"

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: Self.endpoint)!,
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
        apiEndpoint: String = endpoint,
        apiKey: String? = "custom-test-key",
        modelName: String = "whisper-1",
        language: String = "auto",
        requestFormat: CustomTranscriptionRequestFormat = .multipartFormData
    ) -> CustomTranscriptionService {
        CustomTranscriptionService(
            config: .init(
                apiEndpoint: apiEndpoint,
                apiKey: apiKey,
                modelName: modelName,
                language: language,
                requestFormat: requestFormat
            ),
            networkService: networkService
        )
    }

    /// Decodes the captured body as the JSON object the `.jsonBase64` format
    /// is supposed to produce.
    private func capturedJSONBody(_ networkService: MockNetworkService) throws -> [String: Any] {
        let body = try #require(networkService.capturedBody)
        let object = try JSONSerialization.jsonObject(with: body)
        return try #require(object as? [String: Any])
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "custom hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "custom hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsConfiguredEndpoint() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let customEndpoint = "https://my-host.internal/transcribe"
        let sut = makeService(networkService: networkService, apiEndpoint: customEndpoint)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.url?.absoluteString == customEndpoint)
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "custom-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer custom-abc123")
    }

    @Test func requestOmitsAuthorizationHeaderWhenNoAPIKey() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: nil)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(networkService.uploadCallCount == 1)
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
        let sut = makeService(networkService: networkService, modelName: "custom-stt-v2")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"model\"\\s*\\r\\n\\r\\ncustom-stt-v2", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"response_format\"\\s*\\r\\n\\r\\njson", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"temperature\"\\s*\\r\\n\\r\\n0", options: .regularExpression) != nil)
    }

    @Test func bodyIncludesLanguageFieldWhenNotAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "de")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nde", options: .regularExpression) != nil)
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

    // MARK: - JSON / base64 request format

    @Test func jsonFormatSendsApplicationJSONContentTypeWithoutBoundary() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, requestFormat: .jsonBase64)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func jsonFormatInlinesAudioAsBase64DataURI() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, requestFormat: .jsonBase64)

        _ = try await sut.transcribe(audioURL: audio)

        let json = try capturedJSONBody(networkService)
        let file = try #require(json["file"] as? String)
        let prefix = "data:audio/wav;base64,"
        #expect(file.hasPrefix(prefix))

        let payload = String(file.dropFirst(prefix.count))
        let decoded = try #require(Data(base64Encoded: payload))
        #expect(decoded == (try Data(contentsOf: audio)))
    }

    @Test func jsonFormatBodyContainsModelResponseFormatAndTemperature() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(
            networkService: networkService,
            modelName: "custom-stt-v2",
            requestFormat: .jsonBase64
        )

        _ = try await sut.transcribe(audioURL: audio)

        let json = try capturedJSONBody(networkService)
        #expect(json["model"] as? String == "custom-stt-v2")
        #expect(json["response_format"] as? String == "json")
        #expect(json["temperature"] as? Double == 0)
    }

    @Test func jsonFormatIncludesLanguageWhenNotAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "de", requestFormat: .jsonBase64)

        _ = try await sut.transcribe(audioURL: audio)

        let json = try capturedJSONBody(networkService)
        #expect(json["language"] as? String == "de")
    }

    @Test func jsonFormatOmitsLanguageWhenAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "auto", requestFormat: .jsonBase64)

        _ = try await sut.transcribe(audioURL: audio)

        let json = try capturedJSONBody(networkService)
        #expect(json["language"] == nil)
    }

    @Test func jsonFormatSuccessReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "base64 hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, requestFormat: .jsonBase64)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "base64 hello")
        #expect(networkService.uploadCallCount == 1)
    }

    @Test func jsonFormatMissingAudioFileThrowsAudioFileNotFound() async {
        let networkService = MockNetworkService()
        let audio = URL.temporaryDirectory.appending(path: "definitely-not-a-real-file-\(UUID()).wav")
        let sut = makeService(networkService: networkService, requestFormat: .jsonBase64)

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
    }

    // MARK: - Validation / short-circuit

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
