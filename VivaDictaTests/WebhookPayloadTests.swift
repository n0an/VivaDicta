//
//  WebhookPayloadTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import Testing
@testable import VivaDicta

struct WebhookPayloadTests {

    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let transcriptionID = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!

    private func input(
        text: String = "raw transcript",
        enhancedText: String? = nil,
        modeName: String? = "Meeting",
        audioDuration: TimeInterval = 42.5,
        language: String? = "en",
        sourceTag: String? = "shareExtension",
        transcriptionModelName: String? = "Parakeet v3",
        aiModelName: String? = "gpt-test"
    ) -> WebhookPayloadInput {
        WebhookPayloadInput(
            transcriptionID: transcriptionID,
            text: text,
            enhancedText: enhancedText,
            modeName: modeName,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            audioDuration: audioDuration,
            language: language,
            sourceTag: sourceTag,
            transcriptionModelName: transcriptionModelName,
            aiModelName: aiModelName
        )
    }

    private func json(_ payload: WebhookPayload) throws -> [String: Any] {
        let data = try WebhookPayloadBuilder.encode(payload)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Enhanced vs raw

    @Test func enhancedText_becomesText_andTranscriptIsRawText() throws {
        let payload = WebhookPayloadBuilder.payload(
            for: input(enhancedText: "Polished text"), appVersion: "3.13.0", timeZone: berlin
        )
        #expect(payload.text == "Polished text")
        #expect(payload.rawText == "raw transcript")
        #expect(payload.aiModel == "gpt-test")
    }

    @Test func withoutEnhancement_transcriptIsText_andRawTextAndAIModelAreOmitted() throws {
        let object = try json(WebhookPayloadBuilder.payload(
            for: input(enhancedText: nil), appVersion: "3.13.0", timeZone: berlin
        ))
        #expect(object["text"] as? String == "raw transcript")
        #expect(object["rawText"] == nil)
        #expect(object["aiModel"] == nil)
    }

    @Test func blankEnhancedText_fallsBackToTranscript() {
        let payload = WebhookPayloadBuilder.payload(for: input(enhancedText: "  \n"), appVersion: nil, timeZone: berlin)
        #expect(payload.text == "raw transcript")
        #expect(payload.rawText == nil)
    }

    @Test func enhancedTextEqualToTranscript_omitsRawText() {
        let payload = WebhookPayloadBuilder.payload(
            for: input(enhancedText: "raw transcript"), appVersion: nil, timeZone: berlin
        )
        #expect(payload.rawText == nil)
    }

    // MARK: - Omitted fields

    @Test func unknownValues_areOmittedNotNull() throws {
        let object = try json(WebhookPayloadBuilder.payload(
            for: input(
                modeName: nil, audioDuration: 0, language: nil, sourceTag: nil,
                transcriptionModelName: nil, aiModelName: nil
            ),
            appVersion: nil,
            timeZone: berlin
        ))
        #expect(Set(object.keys) == ["id", "text", "textContent", "createdAt", "app", "platform"])
        #expect(!object.values.contains { $0 is NSNull })
    }

    @Test(arguments: ["auto", "AUTO", "", "  "])
    func autoOrEmptyLanguage_isOmitted(language: String) throws {
        let object = try json(WebhookPayloadBuilder.payload(for: input(language: language), appVersion: nil, timeZone: berlin))
        #expect(object["language"] == nil)
    }

    @Test func fullPayload_hasEveryContractField() throws {
        let object = try json(WebhookPayloadBuilder.payload(
            for: input(enhancedText: "Polished"), appVersion: "3.13.0", timeZone: berlin
        ))
        #expect(object["id"] as? String == transcriptionID.uuidString)
        #expect(object["mode"] as? String == "Meeting")
        #expect(object["duration"] as? Double == 42.5)
        #expect(object["language"] as? String == "en")
        #expect(object["source"] as? String == "shareExtension")
        #expect(object["transcriptionModel"] as? String == "Parakeet v3")
        #expect(object["app"] as? String == "VivaDicta")
        #expect(object["appVersion"] as? String == "3.13.0")
        #expect(object["platform"] as? String == "iOS")
    }

    @Test func createdAt_isISO8601WithTimeZoneOffset() {
        let payload = WebhookPayloadBuilder.payload(for: input(), appVersion: nil, timeZone: berlin)
        #expect(payload.createdAt == "2027-01-15T09:00:00+01:00")
    }

    @Test func longText_isNeverTruncated() throws {
        let long = String(repeating: "word ", count: 60_000) // ~300 KB
        let data = try WebhookPayloadBuilder.encode(
            WebhookPayloadBuilder.payload(for: input(text: long), appVersion: nil, timeZone: berlin)
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((object["text"] as? String)?.count == long.count)
    }

    // MARK: - Request

    @Test func request_carriesContractHeaders() {
        let request = WebhookRequestBuilder.request(
            url: URL(string: "https://example.com/hooks/test")!,
            bearerToken: "secret-token",
            idempotencyKey: transcriptionID.uuidString,
            appVersion: "3.13.0"
        )
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == transcriptionID.uuidString)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "VivaDicta/3.13.0")
    }

    @Test func request_withoutToken_hasNoAuthorizationHeader() {
        let request = WebhookRequestBuilder.request(
            url: URL(string: "https://example.com/hooks/test")!,
            bearerToken: nil,
            idempotencyKey: "key",
            appVersion: "3.13.0"
        )
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: - URL validation

    @Test func validator_acceptsHTTPS() {
        #expect((try? WebhookURLValidator.validate(" https://example.com/hooks/a?x=1 ").get())?.absoluteString
                == "https://example.com/hooks/a?x=1")
    }

    @Test func validator_rejectsHTTPAndGarbage() {
        #expect(WebhookURLValidator.validate("http://example.com/hooks") == .failure(.notHTTPS))
        #expect(WebhookURLValidator.validate("") == .failure(.empty))
        #expect(WebhookURLValidator.validate("example.com/hooks") == .failure(.malformed))
        #expect(WebhookURLValidator.validate("https://") == .failure(.malformed))
    }
}

/// Stored modes from versions without webhooks must keep decoding.
@Suite(.serialized)
struct VivaModeWebhookDecodingTests {

    private func modePayload(webhookID: String?) throws -> Data {
        var payload: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Meeting",
            "transcriptionProvider": "deepgram",
            "transcriptionModel": "nova-3",
            "aiModel": "",
            "aiEnhanceEnabled": false,
            "speakerLabelsEnabled": false
        ]
        if let webhookID { payload["webhookID"] = webhookID }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    @Test func modeSavedBeforeWebhooks_decodesWithNoWebhook() throws {
        let mode = try JSONDecoder().decode(VivaMode.self, from: modePayload(webhookID: nil))
        #expect(mode.webhookID == nil)
        #expect(mode.name == "Meeting")
    }

    @Test func webhookID_roundTrips() throws {
        let id = UUID()
        let mode = try JSONDecoder().decode(VivaMode.self, from: modePayload(webhookID: id.uuidString))
        #expect(mode.webhookID == id)

        let reencoded = try JSONDecoder().decode(VivaMode.self, from: JSONEncoder().encode(mode))
        #expect(reencoded.webhookID == id)
    }

    @Test func modeWithoutWebhook_encodesNoKey() throws {
        let mode = try JSONDecoder().decode(VivaMode.self, from: modePayload(webhookID: nil))
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(mode)) as? [String: Any])
        #expect(object["webhookID"] == nil)
    }

    @Test @MainActor func clearingADeletedWebhook_detachesOnlyThatWebhook() {
        let deleted = UUID()
        let kept = UUID()
        let defaults = UserDefaults(suiteName: "VivaModeWebhookDecodingTests-\(UUID().uuidString)")!
        let service = AIService(userDefaults: defaults)
        service.modes = [
            VivaMode(id: UUID(), name: "A", transcriptionProvider: .whisperKit, transcriptionModel: "", aiModel: "", aiEnhanceEnabled: false, webhookID: deleted),
            VivaMode(id: UUID(), name: "B", transcriptionProvider: .whisperKit, transcriptionModel: "", aiModel: "", aiEnhanceEnabled: false, webhookID: kept)
        ]
        service.clearWebhookReferences(to: deleted)
        #expect(service.modes.map(\.webhookID) == [nil, kept])
    }
}
