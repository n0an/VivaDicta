//
//  WebhookTextContentAndRecordedAtTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.11.06
//

import Foundation
import Testing
@testable import VivaDicta

struct WebhookTextContentPayloadTests {

    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func input(enhancedText: String?, recordedAt: Date? = nil) -> WebhookPayloadInput {
        WebhookPayloadInput(
            transcriptionID: UUID(),
            text: "raw transcript",
            enhancedText: enhancedText,
            modeName: "Meeting",
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            recordedAt: recordedAt,
            audioDuration: 42,
            language: "en",
            sourceTag: "shareExtension",
            transcriptionModelName: "Parakeet v3",
            aiModelName: "gpt-test"
        )
    }

    private func json(_ payload: WebhookPayload) throws -> [String: Any] {
        let data = try WebhookPayloadBuilder.encode(payload)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    struct Expectation: Sendable, CustomTestStringConvertible {
        let option: WebhookTextContent
        let enhancedText: String?
        let text: String
        let rawText: String?
        let aiModel: String?

        var testDescription: String { "\(option.rawValue), processed: \(enhancedText != nil)" }
    }

    @Test(arguments: [
        // Both: today's behavior.
        Expectation(option: .both, enhancedText: "Polished", text: "Polished", rawText: "raw transcript", aiModel: "gpt-test"),
        Expectation(option: .both, enhancedText: nil, text: "raw transcript", rawText: nil, aiModel: nil),
        // Last processed only: never rawText.
        Expectation(option: .processed, enhancedText: "Polished", text: "Polished", rawText: nil, aiModel: "gpt-test"),
        Expectation(option: .processed, enhancedText: nil, text: "raw transcript", rawText: nil, aiModel: nil),
        // Original only: the transcript, no rawText, no aiModel.
        Expectation(option: .original, enhancedText: "Polished", text: "raw transcript", rawText: nil, aiModel: nil),
        Expectation(option: .original, enhancedText: nil, text: "raw transcript", rawText: nil, aiModel: nil),
    ])
    func payload_followsTheTextContentOption(expected: Expectation) throws {
        let object = try json(WebhookPayloadBuilder.payload(
            for: input(enhancedText: expected.enhancedText),
            textContent: expected.option,
            appVersion: "3.13.0",
            timeZone: berlin
        ))
        #expect(object["text"] as? String == expected.text)
        #expect(object["rawText"] as? String == expected.rawText)
        #expect(object["aiModel"] as? String == expected.aiModel)
        #expect(object["textContent"] as? String == expected.option.rawValue)
        // The rest of contract v1 is unchanged.
        #expect(object["mode"] as? String == "Meeting")
        #expect(object["createdAt"] as? String == "2027-01-15T09:00:00+01:00")
    }

    @Test func defaultOption_isBoth() {
        let payload = WebhookPayloadBuilder.payload(for: input(enhancedText: "Polished"), appVersion: nil, timeZone: berlin)
        #expect(payload.textContent == "both")
        #expect(payload.rawText == "raw transcript")
    }

    @Test(arguments: WebhookTextContent.allCases)
    func testPayload_honoursTheOption(option: WebhookTextContent) {
        let payload = WebhookPayloadBuilder.testPayload(textContent: option, appVersion: nil, timeZone: berlin)
        #expect(payload.textContent == option.rawValue)
        #expect((payload.rawText != nil) == (option == .both))
        #expect(payload.text == (option == .original
            ? "this is a test message from viva dicta"
            : "This is a test message from VivaDicta."))
    }

    // MARK: - recordedAt

    @Test func recordedAt_isISO8601WithTimeZoneOffset() throws {
        let recorded = Date(timeIntervalSince1970: 1_800_000_000 - 26 * 3600)
        let object = try json(WebhookPayloadBuilder.payload(
            for: input(enhancedText: nil, recordedAt: recorded), appVersion: nil, timeZone: berlin
        ))
        #expect(object["recordedAt"] as? String == "2027-01-14T07:00:00+01:00")
        // createdAt keeps its meaning: when the note was created.
        #expect(object["createdAt"] as? String == "2027-01-15T09:00:00+01:00")
    }

    @Test func unknownRecordedAt_isOmittedNotNull() throws {
        let data = try WebhookPayloadBuilder.encode(WebhookPayloadBuilder.payload(
            for: input(enhancedText: nil, recordedAt: nil), appVersion: nil, timeZone: berlin
        ))
        #expect(!String(decoding: data, as: UTF8.self).contains("recordedAt"))
    }

    @Test @MainActor func storedRecordedAt_reachesThePayloadInput() {
        let recorded = Date(timeIntervalSince1970: 1_799_000_000)
        let transcription = Transcription(text: "note", audioDuration: 5)
        #expect(WebhookPayloadBuilder.input(for: transcription, modeName: nil, language: nil).recordedAt == nil)

        transcription.recordedAt = recorded
        #expect(WebhookPayloadBuilder.input(for: transcription, modeName: nil, language: nil).recordedAt == recorded)
    }
}

struct WebhookDefinitionTextContentDecodingTests {

    private let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func decode(_ json: String) throws -> WebhookDefinition {
        try JSONDecoder().decode(WebhookDefinition.self, from: Data(json.utf8))
    }

    @Test func webhookSavedBeforeTheOption_decodesAsBoth() throws {
        let webhook = try decode("""
        {"id":"\(id.uuidString)","name":"Meetings","url":"https://example.com/hooks/meetings","isEnabled":true,"hasBearerToken":false}
        """)
        #expect(webhook.textContent == .both)
        #expect(webhook.name == "Meetings")
    }

    @Test func unknownValue_fromANewerVersion_decodesAsBoth() throws {
        let webhook = try decode("""
        {"id":"\(id.uuidString)","name":"Meetings","url":"https://example.com/hooks/meetings","textContent":"summaryOnly"}
        """)
        #expect(webhook.textContent == .both)
    }

    @Test(arguments: WebhookTextContent.allCases)
    func textContent_roundTrips(option: WebhookTextContent) throws {
        let webhook = WebhookDefinition(name: "A", url: URL(string: "https://example.com/hooks/a")!, textContent: option)
        let decoded = try JSONDecoder().decode(WebhookDefinition.self, from: JSONEncoder().encode(webhook))
        #expect(decoded.textContent == option)
    }
}

struct RecordingTimeTests {

    private func makeFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).bin")
        try Data([0, 1, 2, 3]).write(to: url)
        return url
    }

    @Test func liveRecordingStart_isUsedAsIs() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(await RecordingTime.known(start).resolve(audioURL: URL(filePath: "/nonexistent")) == start)
    }

    @Test func importedFile_usesTheOriginalsCreationDate() async throws {
        let copy = try makeFile()
        defer { try? FileManager.default.removeItem(at: copy) }
        let importedAt = Date()
        let recorded = importedAt.addingTimeInterval(-2 * 3600)

        let result = await RecordingTime.imported(fileCreationDate: recorded, importedAt: importedAt).resolve(audioURL: copy)

        #expect(result == recorded)
    }

    /// The date was lost on the way in: the original carries the import time.
    @Test func importedFile_dateEqualToTheImportTime_isOmitted() async throws {
        let copy = try makeFile()
        defer { try? FileManager.default.removeItem(at: copy) }
        let importedAt = Date()

        let result = await RecordingTime.imported(fileCreationDate: importedAt, importedAt: importedAt).resolve(audioURL: copy)

        #expect(result == nil)
    }

    @Test func importedFile_withoutAnyDate_isOmitted() async throws {
        let copy = try makeFile()
        defer { try? FileManager.default.removeItem(at: copy) }

        #expect(await RecordingTime.imported(fileCreationDate: nil, importedAt: Date()).resolve(audioURL: copy) == nil)
    }

    @Test func importing_readsTheFileCreationDateBeforeTheCopy() throws {
        let original = try makeFile()
        defer { try? FileManager.default.removeItem(at: original) }
        let recorded = Date(timeIntervalSince1970: 1_790_000_000)
        try FileManager.default.setAttributes([.creationDate: recorded], ofItemAtPath: original.path)
        let importedAt = Date()

        #expect(RecordingTime.importing(from: original, at: importedAt) == .imported(fileCreationDate: recorded, importedAt: importedAt))
    }
}

struct WatchRecordingStartTests {

    @Test func exactStartFromTheWatch_isPreferred() {
        let start = PhoneWatchConnectivityService.recordingStart(metadata: [
            "recordingStartedAt": 1_799_999_900.25,
            "timestamp": 1_800_000_000.0,
            "duration": 95.0,
        ])
        #expect(start == Date(timeIntervalSince1970: 1_799_999_900.25))
    }

    /// Older watch builds send only the stop time and the length.
    @Test func start_isTheStopTimeMinusTheDuration() {
        let start = PhoneWatchConnectivityService.recordingStart(metadata: [
            "timestamp": 1_800_000_000.0,
            "duration": 95.5,
        ])
        #expect(start == Date(timeIntervalSince1970: 1_800_000_000 - 95.5))
    }

    @Test(arguments: [
        (timestamp: nil, duration: 10.0),
        (timestamp: 1_800_000_000.0, duration: nil),
        (timestamp: nil, duration: nil),
    ] as [(timestamp: Double?, duration: Double?)])
    func missingMetadata_givesNoStart(timestamp: Double?, duration: Double?) {
        var metadata: [String: Any] = ["sourceTag": "appleWatch"]
        metadata["timestamp"] = timestamp
        metadata["duration"] = duration
        #expect(PhoneWatchConnectivityService.recordingStart(metadata: metadata) == nil)
    }

    @Test func queuedItemFromAnOlderVersion_decodesWithoutRecordedAt() throws {
        let item = BackgroundWorkItem(audioFileURL: URL(filePath: "/tmp/watch.m4a"), sourceTag: "appleWatch", modeId: nil)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        object.removeValue(forKey: "recordedAt")

        let decoded = try JSONDecoder().decode(BackgroundWorkItem.self, from: JSONSerialization.data(withJSONObject: object))

        #expect(decoded.recordedAt == nil)
        #expect(decoded.sourceTag == "appleWatch")
    }
}
