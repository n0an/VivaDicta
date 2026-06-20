// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `DeepgramTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Unlike the OpenAI/Groq services, Deepgram sends the
/// raw audio bytes as the request body (not multipart) and carries its options
/// in URL query parameters, so the assertions check the URL path + query items
/// and the raw body rather than a multipart payload.
///
/// Verifies request shape (URL, method, headers, query, raw body) and response
/// handling (success, non-2xx, undecodable JSON). Retry-path tests are
/// intentionally skipped here - retry semantics belong on `NetworkRetry`'s own
/// tests.
///
/// Each test creates a fresh `MockNetworkService`, so there's no shared mutable
/// state and the suite is safe to run in parallel with other suites.
@Suite(.tags(.networking))
struct DeepgramTranscriptionServiceTests {

    // MARK: - Test Helpers

    /// Writes a small payload to a unique temp URL and returns it. The bytes
    /// don't need to be valid audio - `DeepgramTranscriptionService` just
    /// forwards them as the raw request body.
    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.deepgram.com/v1/listen")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func stubSuccess(on networkService: MockNetworkService, text: String) {
        let body = Data(#"{"results":{"channels":[{"alternatives":[{"transcript":"\#(text)","confidence":0.99}]}]}}"#.utf8)
        networkService.stubUploadResponse = .success((body, makeHTTPResponse(200)))
    }

    /// Resolves the captured request's URL into `URLComponents`, so individual
    /// query items can be checked without depending on query-item order.
    private func components(of request: URLRequest) throws -> URLComponents {
        let url = try #require(request.url)
        return try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    }

    private func makeService(
        networkService: MockNetworkService,
        apiKey: String = "dg-test-key",
        modelName: String = "nova-3",
        language: String = "auto",
        vocabulary: [String] = [],
        isSpeakerDiarizationEnabled: Bool = false
    ) -> DeepgramTranscriptionService {
        DeepgramTranscriptionService(
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

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "deepgram hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "deepgram hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsDeepgramListenEndpoint() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let comps = try components(of: req)
        #expect(comps.host == "api.deepgram.com")
        #expect(comps.path == "/v1/listen")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSetsModelQueryParameter() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "nova-2")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "model", value: "nova-2")))
        #expect(items.contains(URLQueryItem(name: "smart_format", value: "true")))
        #expect(items.contains(URLQueryItem(name: "punctuate", value: "true")))
        #expect(items.contains(URLQueryItem(name: "paragraphs", value: "true")))
    }

    @Test func requestSendsTokenAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "dg-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Token dg-abc123")
    }

    @Test func requestSendsRawAudioBytesAsBody() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        // Deepgram forwards the file's bytes verbatim, not a multipart payload.
        #expect(body == Data([0x52, 0x49, 0x46, 0x46]))
    }

    @Test func requestIncludesLanguageQueryWhenNotAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "en")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "language", value: "en")))
    }

    @Test func requestOmitsLanguageQueryWhenAuto() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "auto")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        #expect(items.contains { $0.name == "language" } == false)
    }

    // MARK: - Diarization

    @Test func requestOmitsDiarizationQueriesWhenDisabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: false)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        #expect(items.contains { $0.name == "diarize" } == false)
        #expect(items.contains { $0.name == "utterances" } == false)
    }

    @Test func requestIncludesDiarizationQueriesWhenEnabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "diarize", value: "true")))
        #expect(items.contains(URLQueryItem(name: "utterances", value: "true")))
    }

    // MARK: - Vocabulary

    @Test func requestOmitsKeytermQueriesWhenVocabularyIsEmpty() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "nova-3", vocabulary: [])

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        #expect(items.contains { $0.name == "keyterm" } == false)
        #expect(items.contains { $0.name == "keywords" } == false)
    }

    @Test func requestUsesKeytermForNova3Vocabulary() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "nova-3", vocabulary: ["SwiftUI", "Kubernetes"])

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        let keyterms = items.filter { $0.name == "keyterm" }.compactMap(\.value)
        #expect(keyterms.contains("SwiftUI"))
        #expect(keyterms.contains("Kubernetes"))
        #expect(items.contains { $0.name == "keywords" } == false)
    }

    @Test func requestUsesKeywordsForNonNova3Vocabulary() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "nova-2", vocabulary: ["SwiftUI"])

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let items = try components(of: req).queryItems ?? []
        let keywords = items.filter { $0.name == "keywords" }.compactMap(\.value)
        #expect(keywords.contains("SwiftUI"))
        #expect(items.contains { $0.name == "keyterm" } == false)
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
            Data(#"{"err_msg":"invalid key"}"#.utf8),
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
