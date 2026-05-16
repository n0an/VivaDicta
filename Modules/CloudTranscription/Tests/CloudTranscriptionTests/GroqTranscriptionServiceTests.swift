// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `GroqTranscriptionService` end-to-end with a stubbed
/// `MockURLSession`. Verifies request shape (URL, method, headers,
/// multipart body) and response handling (success, non-2xx, undecodable
/// JSON), plus the Groq-specific vocabulary-prompt path.
///
/// Mirrors the structure of `OpenAITranscriptionServiceTests`. Retry-path
/// tests are intentionally skipped here - retry semantics belong on
/// `NetworkRetry`'s own tests.
struct GroqTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!,
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
        apiKey: String = "gsk-test-key",
        modelName: String = "whisper-large-v3",
        language: String = "auto",
        vocabulary: [String] = []
    ) -> GroqTranscriptionService {
        GroqTranscriptionService(
            config: .init(
                apiKey: apiKey,
                modelName: modelName,
                language: language,
                vocabulary: vocabulary
            ),
            urlSession: session
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "groq hello")
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "groq hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(session.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsGroqTranscriptionsEndpoint() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.groq.com/openai/v1/audio/transcriptions")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, apiKey: "gsk-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer gsk-abc123")
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
        let sut = makeService(session: session, modelName: "whisper-large-v3")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"model\"\\s*\\r\\n\\r\\nwhisper-large-v3", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"response_format\"\\s*\\r\\n\\r\\njson", options: .regularExpression) != nil)
        #expect(bodyString.range(of: "name=\"temperature\"\\s*\\r\\n\\r\\n0", options: .regularExpression) != nil)
    }

    @Test func bodyIncludesLanguageFieldWhenNotAuto() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nfr", options: .regularExpression) != nil)
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

    // MARK: - Vocabulary / prompt (Groq-specific)

    @Test func bodyOmitsPromptFieldWhenVocabularyIsEmpty() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, vocabulary: [])

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(!bodyString.contains("name=\"prompt\""))
    }

    @Test func bodyIncludesPromptFieldWhenVocabularyProvided() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, vocabulary: ["SwiftUI", "Kubernetes"])

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"prompt\""))
        #expect(bodyString.contains("SwiftUI, Kubernetes"))
        #expect(bodyString.contains("Prefer these spellings"))
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
