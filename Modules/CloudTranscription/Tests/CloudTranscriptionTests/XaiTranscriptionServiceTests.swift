// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `XaiTranscriptionService` end-to-end with a stubbed
/// `MockURLSession`. Verifies request shape (URL, method, headers,
/// multipart body) and response handling (success, non-2xx, undecodable
/// JSON), plus the xAI-specific `format`/`file-last` body ordering.
struct XaiTranscriptionServiceTests {

    // MARK: - Test Helpers

    private func makeAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.x.ai/v1/stt")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func stubSuccess(on session: MockURLSession, text: String) {
        let body = Data(#"{"text":"\#(text)"}"#.utf8)
        session.stubUploadResponse = .success((body, makeHTTPResponse(200)))
    }

    private func makeService(
        session: MockURLSession,
        apiKey: String = "xai-test-key",
        language: String = "auto",
        formatted: Bool = true
    ) -> XaiTranscriptionService {
        XaiTranscriptionService(
            config: .init(
                apiKey: apiKey,
                language: language,
                formatted: formatted
            ),
            urlSession: session
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "xai hello")
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "xai hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(session.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsXaiSttEndpoint() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.x.ai/v1/stt")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, apiKey: "xai-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(session.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer xai-abc123")
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

    @Test func bodyContainsFormatTrueByDefault() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"format\"\\s*\\r\\n\\r\\ntrue", options: .regularExpression) != nil)
    }

    @Test func bodySendsFormatFalseWhenFormattedDisabled() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, formatted: false)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"format\"\\s*\\r\\n\\r\\nfalse", options: .regularExpression) != nil)
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

    @Test func bodyPlacesFileFieldLastPerXaiSpec() async throws {
        let session = MockURLSession()
        stubSuccess(on: session, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(session: session, language: "en")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(session.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        let formatRange = try #require(bodyString.range(of: "name=\"format\""))
        let languageRange = try #require(bodyString.range(of: "name=\"language\""))
        let fileRange = try #require(bodyString.range(of: "name=\"file\""))
        #expect(formatRange.lowerBound < fileRange.lowerBound)
        #expect(languageRange.lowerBound < fileRange.lowerBound)
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
