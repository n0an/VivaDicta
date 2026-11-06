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
    /// Final text: the AI-processed text when processing ran, otherwise the transcript.
    let text: String
    /// The original transcript, only when it differs from ``text``.
    let rawText: String?
    let mode: String?
    /// ISO 8601 with a time zone offset, the recording time.
    let createdAt: String
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
        appVersion: String?,
        timeZone: TimeZone = .current
    ) -> WebhookPayload {
        let enhanced = nonEmpty(input.enhancedText)
        let finalText = enhanced ?? input.text
        let usedEnhanced = enhanced != nil

        return WebhookPayload(
            id: input.transcriptionID.uuidString,
            text: finalText,
            rawText: finalText == input.text ? nil : input.text,
            mode: nonEmpty(input.modeName),
            createdAt: iso8601(input.timestamp, timeZone: timeZone),
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

    /// A sample payload for the "Send test" button.
    static func testPayload(appVersion: String?, now: Date = Date(), timeZone: TimeZone = .current) -> WebhookPayload {
        payload(
            for: WebhookPayloadInput(
                transcriptionID: UUID(),
                text: "This is a test message from VivaDicta.",
                enhancedText: nil,
                modeName: "Test",
                timestamp: now,
                audioDuration: 3,
                language: "en",
                sourceTag: "test",
                transcriptionModelName: nil,
                aiModelName: nil
            ),
            appVersion: appVersion,
            timeZone: timeZone
        )
    }

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
