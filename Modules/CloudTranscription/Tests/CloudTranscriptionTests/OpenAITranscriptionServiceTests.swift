// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `OpenAITranscriptionService` end-to-end with a stubbed
/// `URLSession` (via `MockURLProtocol`). They verify request shape (URL,
/// method, headers, multipart body) and response handling (success,
/// non-2xx, undecodable JSON). Retry-path tests are intentionally skipped
/// here - retry semantics belong on `NetworkRetry`.
@Suite(.serialized)
struct OpenAITranscriptionServiceTests {

    // MARK: - Test Helpers

    /// Writes a small payload to a unique temp URL and returns it. The bytes
    /// don't have to be valid audio - `OpenAITranscriptionService` just
    /// forwards them in the multipart body.
    private func makeAudioFile() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    private func makeService(
        apiKey: String = "sk-test-key",
        modelName: String = "whisper-1",
        language: String = "auto"
    ) -> OpenAITranscriptionService {
        OpenAITranscriptionService(
            config: .init(apiKey: apiKey, modelName: modelName, language: language),
            urlSession: makeMockedURLSession()
        )
    }

    private func stubSuccess(text: String) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body = Data(#"{"text":"\#(text)","language":"en","duration":0.5}"#.utf8)
            return (response, body)
        }
    }

    private func stubStatus(_ code: Int, message: String = "error") {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(message.utf8))
        }
    }

    init() {
        MockURLProtocol.reset()
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        stubSuccess(text: "hello world")
        let audio = try makeAudioFile()
        let service = makeService()

        let result = try await service.transcribe(audioURL: audio)

        #expect(result.text == "hello world")
        #expect(result.isSpeakerAttributed == false)
    }

    // MARK: - Request shape

    @Test func requestTargetsOpenAITranscriptionsEndpoint() async throws {
        stubSuccess(text: "ok")
        let audio = try makeAudioFile()
        _ = try await makeService().transcribe(audioURL: audio)

        let req = try #require(MockURLProtocol.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        stubSuccess(text: "ok")
        let audio = try makeAudioFile()
        _ = try await makeService(apiKey: "sk-abc123").transcribe(audioURL: audio)

        let req = try #require(MockURLProtocol.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-abc123")
    }

    @Test func requestSendsMultipartContentTypeWithBoundary() async throws {
        stubSuccess(text: "ok")
        let audio = try makeAudioFile()
        _ = try await makeService().transcribe(audioURL: audio)

        let req = try #require(MockURLProtocol.capturedRequest)
        let contentType = try #require(req.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary=Boundary-"))
    }

    @Test func bodyContainsModelAndResponseFormatFields() async throws {
        stubSuccess(text: "ok")
        let audio = try makeAudioFile()
        _ = try await makeService(modelName: "whisper-1").transcribe(audioURL: audio)

        let body = try #require(MockURLProtocol.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"model\""))
        #expect(bodyString.contains("whisper-1"))
        #expect(bodyString.contains("name=\"response_format\""))
        #expect(bodyString.contains("json"))
        #expect(bodyString.contains("name=\"temperature\""))
    }

    @Test func bodyIncludesLanguageFieldWhenNotAuto() async throws {
        stubSuccess(text: "ok")
        let audio = try makeAudioFile()
        _ = try await makeService(language: "en").transcribe(audioURL: audio)

        let body = try #require(MockURLProtocol.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"language\""))
        // The "en" value follows the language field header; verify both present.
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nen", options: .regularExpression) != nil)
    }

    @Test func bodyOmitsLanguageFieldWhenAuto() async throws {
        stubSuccess(text: "ok")
        let audio = try makeAudioFile()
        _ = try await makeService(language: "auto").transcribe(audioURL: audio)

        let body = try #require(MockURLProtocol.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(!bodyString.contains("name=\"language\""))
    }

    // MARK: - Validation / short-circuit

    @Test func missingAPIKeyThrowsBeforeMakingRequest() async throws {
        let audio = try makeAudioFile()
        let service = makeService(apiKey: "")

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await service.transcribe(audioURL: audio)
        }
        #expect(MockURLProtocol.capturedRequest == nil, "no network call should be made when API key is empty")
    }

    @Test func missingAudioFileThrowsAudioFileNotFound() async {
        let audio = URL(fileURLWithPath: "/tmp/definitely-not-a-real-file-\(UUID()).wav")
        let service = makeService()

        await #expect(throws: CloudTranscriptionError.self) {
            _ = try await service.transcribe(audioURL: audio)
        }
    }

    // MARK: - Response handling

    @Test func nonSuccessStatusThrowsApiRequestFailed() async throws {
        // 401 is not retried (only 429 + 5xx are), so this throws immediately.
        stubStatus(401, message: "{\"error\":\"invalid key\"}")
        let audio = try makeAudioFile()
        let service = makeService()

        do {
            _ = try await service.transcribe(audioURL: audio)
            Issue.record("expected apiRequestFailed to throw")
        } catch let CloudTranscriptionError.apiRequestFailed(statusCode, message) {
            #expect(statusCode == 401)
            #expect(message.contains("invalid key"))
        } catch {
            Issue.record("expected CloudTranscriptionError.apiRequestFailed, got \(error)")
        }
    }

    @Test func undecodableJSONOn200ThrowsNoTranscriptionReturned() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("not json".utf8))
        }
        let audio = try makeAudioFile()
        let service = makeService()

        do {
            _ = try await service.transcribe(audioURL: audio)
            Issue.record("expected noTranscriptionReturned to throw")
        } catch CloudTranscriptionError.noTranscriptionReturned {
            // expected
        } catch {
            Issue.record("expected noTranscriptionReturned, got \(error)")
        }
    }
}
