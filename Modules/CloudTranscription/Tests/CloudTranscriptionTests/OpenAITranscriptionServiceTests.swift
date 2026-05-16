// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `OpenAITranscriptionService` end-to-end with a stubbed
/// `MockURLSession` (`URLSessionProtocol` conformer from `NetworkingMocks`).
/// Verifies request shape (URL, method, headers, multipart body) and
/// response handling (success, non-2xx, undecodable JSON).
///
/// Retry-path tests are intentionally skipped here - retry semantics belong
/// on `NetworkRetry`'s own tests.
///
/// Each test creates a fresh `MockURLSession`, so there's no shared mutable
/// state and the suite is safe to run in parallel with other suites.
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

    private func stubSuccess(on session: MockURLSession, text: String) {
        let body = Data(#"{"text":"\#(text)","language":"en","duration":0.5}"#.utf8)
        session.stubUploadResponse = .success((body, makeHTTPResponse(200)))
    }

    private func makeService(
        session: MockURLSession,
        apiKey: String = "sk-test-key",
        modelName: String = "whisper-1",
        language: String = "auto"
    ) -> OpenAITranscriptionService {
        OpenAITranscriptionService(
            config: .init(apiKey: apiKey, modelName: modelName, language: language),
            urlSession: session
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "hello world")
        let audio = try makeAudioFile()

        let sut = makeService(session: session)
        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "hello world")
        #expect(result.isSpeakerAttributed == false)
        #expect(session.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsOpenAITranscriptionsEndpoint() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(session: session)
        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(session: session, apiKey: "sk-abc123")
        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-abc123")
    }

    @Test func requestSendsMultipartContentTypeWithBoundary() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(session: session)
        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        let contentType = try #require(req.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary=Boundary-"))
    }

    @Test func bodyContainsModelAndResponseFormatFields() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(session: session, modelName: "whisper-1")
        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        // Regex form (rather than separate `contains` checks) ensures each
        // value immediately follows its multipart field header, so a
        // misordered body can't pass by coincidence.
        #expect(bodyString.range(of: "name=\"model\"\\s*\\r\\n\\r\\nwhisper-1", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"response_format\"\\s*\\r\\n\\r\\njson", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"temperature\"\\s*\\r\\n\\r\\n0", options: .regularExpression) != nil)
    }

    @Test func bodyIncludesLanguageFieldWhenNotAuto() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(session: session, language: "en")
        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nen", options: .regularExpression) != nil)
    }

    @Test func bodyOmitsLanguageFieldWhenAuto() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()

        let sut = makeService(session: session, language: "auto")
        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(!bodyString.contains("name=\"language\""))
    }

    // MARK: - Validation / short-circuit

    @Test func missingAPIKeyThrowsBeforeMakingRequest() async throws {
        let session = MockURLSession()
        let audio = try makeAudioFile()
        let sut = makeService(session: session, apiKey: "")

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
        #expect(session.uploadCallCount == 0, "no network call should be made when API key is empty")
    }

    @Test func missingAudioFileThrowsAudioFileNotFound() async {
        let session = MockURLSession()
        let audio = URL.temporaryDirectory.appending(path: "definitely-not-a-real-file-\(UUID()).wav")
        let sut = makeService(session: session)

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: audio)
        }
    }

    // MARK: - Response handling

    @Test func nonSuccessStatusThrowsApiRequestFailed() async throws {
        // 401 is not retried (only 429 + 5xx are), so this throws immediately.
        let session = MockURLSession()
        session.stubUploadResponse = .success((
            Data(#"{"error":"invalid key"}"#.utf8),
            makeHTTPResponse(401)
        ))
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        do {
            _ = try await sut.transcribe(audioURL: audio)
            Issue.record("expected apiRequestFailed to throw")
        } catch let CloudTranscriptionError.apiRequestFailed(statusCode, message) {
            #expect(statusCode == 401)
            #expect(message.contains("invalid key"))
        } catch {
            Issue.record("expected CloudTranscriptionError.apiRequestFailed, got \(error)")
        }
    }

    @Test func undecodableJSONOn200ThrowsNoTranscriptionReturned() async throws {
        let session = MockURLSession()
        session.stubUploadResponse = .success((Data("not json".utf8), makeHTTPResponse(200)))
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        do {
            _ = try await sut.transcribe(audioURL: audio)
            Issue.record("expected noTranscriptionReturned to throw")
        } catch CloudTranscriptionError.noTranscriptionReturned {
            // expected
        } catch {
            Issue.record("expected noTranscriptionReturned, got \(error)")
        }
    }
}
