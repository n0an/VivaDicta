// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `GeminiTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Verifies request shape (URL, method, `x-goog-api-key`
/// header, inlined-base64 JSON body) and response handling (success, non-2xx,
/// undecodable JSON).
///
/// Unlike the OpenAI/Groq services - which `upload` raw `Data` and decode it
/// themselves - Gemini calls `NetworkService.sendJSON`, so the mock is stubbed
/// via `stubSendJSONResponse` with an already-decoded `GeminiResponse`. Error
/// paths are stubbed as `.failure(NetworkError...)` so the service's
/// `asTranscriptionError()` mapping is what's exercised.
///
/// Retry-path tests are intentionally skipped here - retry semantics belong on
/// `NetworkRetry`'s own tests.
@Suite(.tags(.networking))
struct GeminiTranscriptionServiceTests {

    // MARK: - Test Helpers

    /// Writes a tiny RIFF payload to a unique temp URL. The bytes don't need to
    /// be valid audio - the service just base64-encodes whatever it reads.
    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini:generateContent")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    /// Decodes the documented Gemini `generateContent` response shape into the
    /// concrete `GeminiResponse` the mock returns from `sendJSON`. Decoding from
    /// real JSON (rather than a hand-built value) keeps the stub anchored to the
    /// wire format the service expects.
    private func makeGeminiResponse(text: String) throws -> GeminiTranscriptionService.GeminiResponse {
        let json = Data(#"{"candidates":[{"content":{"parts":[{"text":"\#(text)"}]}}]}"#.utf8)
        return try JSONDecoder().decode(GeminiTranscriptionService.GeminiResponse.self, from: json)
    }

    private func stubSuccess(on networkService: MockNetworkService, text: String) throws {
        let response = try makeGeminiResponse(text: text)
        networkService.stubSendJSONResponse = .success(response)
    }

    private func makeService(
        networkService: MockNetworkService,
        apiKey: String = "gemini-test-key",
        modelName: String = "gemini-2.0-flash"
    ) -> GeminiTranscriptionService {
        GeminiTranscriptionService(
            config: .init(apiKey: apiKey, modelName: modelName),
            networkService: networkService
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        try stubSuccess(on: networkService, text: "gemini hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "gemini hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.sendJSONCallCount == 1)
    }

    @Test func successTrimsSurroundingWhitespace() async throws {
        let networkService = MockNetworkService()
        // Leading/trailing whitespace the service trims with
        // `.whitespacesAndNewlines`.
        try stubSuccess(on: networkService, text: "  spaced out  ")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "spaced out")
    }

    // MARK: - Request shape

    @Test func requestTargetsGeminiGenerateContentEndpoint() async throws {
        let networkService = MockNetworkService()
        try stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, modelName: "gemini-2.0-flash")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(
            req.url?.absoluteString
                == "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
        )
        #expect(req.url?.host == "generativelanguage.googleapis.com")
        #expect(req.url?.path == "/v1beta/models/gemini-2.0-flash:generateContent")
        #expect(req.httpMethod == "POST")
    }

    // MARK: - Auth (header, not query param)

    @Test func requestSendsApiKeyInGoogleHeader() async throws {
        let networkService = MockNetworkService()
        try stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "gemini-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "x-goog-api-key") == "gemini-abc123")
        // Gemini puts the key in a header, never on the URL.
        let components = URLComponents(url: try #require(req.url), resolvingAgainstBaseURL: false)
        #expect(components?.queryItems == nil)
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func requestSendsJSONContentType() async throws {
        let networkService = MockNetworkService()
        try stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: - Body

    @Test func bodyInlinesBase64AudioWithMimeTypeAndPrompt() async throws {
        let networkService = MockNetworkService()
        try stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        let body = try #require(req.httpBody)
        let object = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let contents = try #require(object["contents"] as? [[String: Any]])
        let parts = try #require(contents.first?["parts"] as? [[String: Any]])

        // Text part carries the transcription instruction.
        let textValues = parts.compactMap { $0["text"] as? String }
        #expect(textValues.contains { $0.contains("transcribe this audio file") })

        // Audio part inlines the base64-encoded "RIFF" bytes + a MIME type.
        let inlineData = try #require(
            parts.compactMap { $0["inlineData"] as? [String: Any] }.first
        )
        #expect((inlineData["data"] as? String) == Data([0x52, 0x49, 0x46, 0x46]).base64EncodedString())
        #expect((inlineData["mimeType"] as? String)?.isEmpty == false)
    }

    // MARK: - Validation / short-circuit

    @Test func missingAPIKeyThrowsBeforeMakingRequest() async throws {
        let networkService = MockNetworkService()
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "")

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        #expect(networkService.sendJSONCallCount == 0, "no network call should be made when API key is empty")
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
        // The mock's `sendJSON` doesn't validate status itself, so the
        // production `NetworkError.unacceptableStatus` is stubbed directly to
        // exercise the service's `asTranscriptionError()` mapping.
        let networkService = MockNetworkService()
        networkService.stubSendJSONResponse = .failure(
            NetworkError.unacceptableStatus(code: 401, body: Data(#"{"error":"invalid key"}"#.utf8))
        )
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

    @Test func undecodableJSONThrowsNoTranscriptionReturned() async throws {
        // Production `sendJSON` surfaces a decode failure as
        // `NetworkError.decodingFailed`, which the service maps to
        // `noTranscriptionReturned`.
        struct DummyDecodeError: Error {}
        let networkService = MockNetworkService()
        networkService.stubSendJSONResponse = .failure(
            NetworkError.decodingFailed(DummyDecodeError())
        )
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

    @Test func emptyCandidatesThrowsNoTranscriptionReturned() async throws {
        // A 200 that decodes but carries no candidates -> the service's own
        // guard throws `noTranscriptionReturned`.
        let networkService = MockNetworkService()
        let emptyResponse = try JSONDecoder().decode(
            GeminiTranscriptionService.GeminiResponse.self,
            from: Data(#"{"candidates":[]}"#.utf8)
        )
        networkService.stubSendJSONResponse = .success(emptyResponse)
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
