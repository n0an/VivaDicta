// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
@testable import CloudTranscription
import TranscriptionCore

/// Tests exercise `XaiTranscriptionService` end-to-end with a stubbed
/// `MockNetworkService`. Verifies request shape (URL, method, headers,
/// multipart body) and response handling (success, non-2xx, undecodable
/// JSON), plus the xAI-specific `format`/`file-last` body ordering.
@Suite(.tags(.networking))
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

    private func stubSuccess(on networkService: MockNetworkService, text: String) {
        let body = Data(#"{"text":"\#(text)"}"#.utf8)
        networkService.stubUploadResponse = .success((body, makeHTTPResponse(200)))
    }

    private func makeService(
        networkService: MockNetworkService,
        apiKey: String = "xai-test-key",
        language: String = "en",
        formatted: Bool = true,
        isSpeakerDiarizationEnabled: Bool = false
    ) -> XaiTranscriptionService {
        XaiTranscriptionService(
            config: .init(
                apiKey: apiKey,
                language: language,
                formatted: formatted,
                isSpeakerDiarizationEnabled: isSpeakerDiarizationEnabled
            ),
            networkService: networkService
        )
    }

    // MARK: - Success path

    @Test func successReturnsTranscribedText() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "xai hello")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.text == "xai hello")
        #expect(result.isSpeakerAttributed == false)
        #expect(networkService.uploadCallCount == 1)
    }

    // MARK: - Request shape

    @Test func requestTargetsXaiSttEndpoint() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.url?.absoluteString == "https://api.x.ai/v1/stt")
        #expect(req.httpMethod == "POST")
    }

    @Test func requestSendsBearerAuthorizationHeader() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, apiKey: "xai-abc123")

        _ = try await sut.transcribe(audioURL: audio)

        let req = try #require(networkService.capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer xai-abc123")
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

    @Test func bodyContainsFormatTrueByDefault() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"format\"\\s*\\r\\n\\r\\ntrue", options: .regularExpression) != nil)
    }

    @Test func bodySendsFormatFalseWhenFormattedDisabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, formatted: false)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"format\"\\s*\\r\\n\\r\\nfalse", options: .regularExpression) != nil)
    }

    @Test func bodyIncludesLanguageField() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fr")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nfr", options: .regularExpression) != nil)
    }

    @Test func bodyAlwaysSendsLanguageEvenForUnusualCodes() async throws {
        // xAI rejects format=true without a language, so the service must
        // never omit the field. Verify with `fil` (Filipino) since it's xAI's
        // 3-letter outlier and proves no "drop if not in allowlist" sneaks in.
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "fil")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"language\"\\s*\\r\\n\\r\\nfil", options: .regularExpression) != nil)
    }

    @Test func bodyOrdersFieldsAsFormatLanguageFile() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, language: "en")

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        let formatRange = try #require(bodyString.range(of: "name=\"format\""))
        let languageRange = try #require(bodyString.range(of: "name=\"language\""))
        let fileRange = try #require(bodyString.range(of: "name=\"file\""))
        // file MUST be last per xAI docs; strict ordering catches any future
        // reshuffle that happens to keep file last but breaks the rest.
        #expect(formatRange.lowerBound < languageRange.lowerBound)
        #expect(languageRange.lowerBound < fileRange.lowerBound)
    }

    // MARK: - Diarization

    @Test func bodyOmitsDiarizeFieldByDefault() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"diarize\"") == false)
    }

    @Test func bodyIncludesDiarizeTrueWhenEnabled() async throws {
        let networkService = MockNetworkService()
        stubSuccess(on: networkService, text: "ok")
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        _ = try await sut.transcribe(audioURL: audio)

        let body = try #require(networkService.capturedBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.range(of: "name=\"diarize\"\\s*\\r\\n\\r\\ntrue", options: .regularExpression) != nil)
    }

    @Test func diarizationGroupsConsecutiveWordsBySpeaker() async throws {
        let networkService = MockNetworkService()
        let json = #"""
        {"text":"Hello there Hi","words":[
        {"text":"Hello","speaker":0},
        {"text":"there","speaker":0},
        {"text":"Hi","speaker":1}
        ]}
        """#
        networkService.stubUploadResponse = .success((Data(json.utf8), makeHTTPResponse(200)))
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: true)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed)
        #expect(result.text == "Speaker A: Hello there\n\nSpeaker B: Hi")
    }

    @Test func diarizationDisabledReturnsPlainTextEvenWithSpeakerWords() async throws {
        let networkService = MockNetworkService()
        let json = #"{"text":"Hello there","words":[{"text":"Hello","speaker":0},{"text":"there","speaker":1}]}"#
        networkService.stubUploadResponse = .success((Data(json.utf8), makeHTTPResponse(200)))
        let audio = try makeAudioFile()
        let sut = makeService(networkService: networkService, isSpeakerDiarizationEnabled: false)

        let result = try await sut.transcribe(audioURL: audio)

        #expect(result.isSpeakerAttributed == false)
        #expect(result.text == "Hello there")
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
