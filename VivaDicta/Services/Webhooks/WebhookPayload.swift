//
//  WebhookPayload.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation

/// The JSON body POSTed to a webhook (contract v1).
///
/// Optional properties are omitted from the JSON when `nil` (the synthesized
/// `Encodable` conformance uses `encodeIfPresent`), so receivers never see
/// `null` for unknown values.
nonisolated struct WebhookPayload: Encodable, Equatable, Sendable {
    /// Transcription UUID. Stable across retries and manual re-sends.
    let id: String
    /// The text the webhook asked for (see ``textContent``): the last
    /// AI-processed text, or the original transcript.
    let text: String
    /// The original transcript. Only with ``textContent`` `both`, and only when it differs from ``text``.
    let rawText: String?
    /// What ``text`` holds: `original`, `processed` or `both` (``WebhookTextContent``).
    let textContent: String
    let mode: String?
    /// ISO 8601 with a time zone offset, when the note was created (transcribed).
    let createdAt: String
    /// ISO 8601 with a time zone offset, when the audio was recorded.
    /// Omitted when unknown or not trustworthy.
    let recordedAt: String?
    /// Audio length in seconds.
    let duration: Double?
    let language: String?
    let source: String?
    let transcriptionModel: String?
    let aiModel: String?
    let app: String
    let appVersion: String?
    let platform: String
}

/// Plain values copied out of a `Transcription` so payload composition stays a
/// pure function that tests can drive without SwiftData.
nonisolated struct WebhookPayloadInput: Sendable, Equatable {
    var transcriptionID: UUID
    var text: String
    var enhancedText: String?
    var modeName: String?
    var timestamp: Date
    var recordedAt: Date? = nil
    var audioDuration: TimeInterval
    var language: String?
    var sourceTag: String?
    var transcriptionModelName: String?
    var aiModelName: String?
}

nonisolated enum WebhookPayloadBuilder {
    static let appName = "VivaDicta"
    static let platform = "iOS"

    /// The `CFBundleShortVersionString` of the running app, if any.
    static var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static func payload(
        for input: WebhookPayloadInput,
        textContent: WebhookTextContent = .default,
        appVersion: String?,
        timeZone: TimeZone = .current
    ) -> WebhookPayload {
        let enhanced = textContent == .original ? nil : nonEmpty(input.enhancedText)
        let finalText = enhanced ?? input.text
        let usedEnhanced = enhanced != nil
        let rawText = textContent == .both && finalText != input.text ? input.text : nil

        return WebhookPayload(
            id: input.transcriptionID.uuidString,
            text: finalText,
            rawText: rawText,
            textContent: textContent.rawValue,
            mode: nonEmpty(input.modeName),
            createdAt: iso8601(input.timestamp, timeZone: timeZone),
            recordedAt: input.recordedAt.map { iso8601($0, timeZone: timeZone) },
            duration: input.audioDuration > 0 ? input.audioDuration : nil,
            language: normalizedLanguage(input.language),
            source: nonEmpty(input.sourceTag),
            transcriptionModel: nonEmpty(input.transcriptionModelName),
            aiModel: usedEnhanced ? nonEmpty(input.aiModelName) : nil,
            app: appName,
            appVersion: nonEmpty(appVersion),
            platform: platform
        )
    }

    /// A sample payload for the "Send test" button. It has an original and a
    /// processed text, so the webhook's ``WebhookTextContent`` shows in the result.
    static func testPayload(
        textContent: WebhookTextContent = .default,
        appVersion: String?,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> WebhookPayload {
        payload(
            for: WebhookPayloadInput(
                transcriptionID: UUID(),
                text: "this is a test message from viva dicta",
                enhancedText: "This is a test message from VivaDicta.",
                modeName: "Test",
                timestamp: now,
                recordedAt: now.addingTimeInterval(-testRecordingAge),
                audioDuration: 3,
                language: "en",
                sourceTag: "test",
                transcriptionModelName: nil,
                aiModelName: nil
            ),
            textContent: textContent,
            appVersion: appVersion,
            timeZone: timeZone
        )
    }

    /// How long before "now" the sample note was recorded.
    static let testRecordingAge: TimeInterval = 60 * 60

    static func encode(_ payload: WebhookPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    /// `nil`, empty and `"auto"` mean the language is not known.
    static func normalizedLanguage(_ code: String?) -> String? {
        guard let code = nonEmpty(code), code.lowercased() != "auto" else { return nil }
        return code
    }

    static func iso8601(_ date: Date, timeZone: TimeZone) -> String {
        date.formatted(
            Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone)
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}

extension WebhookPayloadBuilder {
    /// Copies the payload-relevant values out of a transcription.
    @MainActor
    static func input(for transcription: Transcription, modeName: String?, language: String?) -> WebhookPayloadInput {
        WebhookPayloadInput(
            transcriptionID: transcription.id,
            text: transcription.text,
            enhancedText: transcription.enhancedText,
            modeName: modeName,
            timestamp: transcription.timestamp,
            recordedAt: transcription.recordedAt,
            audioDuration: transcription.audioDuration,
            language: language,
            sourceTag: transcription.sourceTag,
            transcriptionModelName: transcription.transcriptionModelName,
            aiModelName: transcription.aiEnhancementModelName
        )
    }
}

/// Builds the HTTP request for one delivery attempt.
nonisolated enum WebhookRequestBuilder {
    static let timeout: TimeInterval = 60

    static func request(url: URL, bearerToken: String?, idempotencyKey: String, appVersion: String?) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        request.setValue("\(WebhookPayloadBuilder.appName)/\(appVersion ?? "unknown")", forHTTPHeaderField: "User-Agent")
        if let bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
