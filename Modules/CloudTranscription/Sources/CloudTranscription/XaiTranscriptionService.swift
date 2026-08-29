// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured xAI Speech-to-Text client.
///
/// Endpoint: POST https://api.x.ai/v1/stt with multipart/form-data.
/// The xAI STT API has no `model` field; the form fields are `format`,
/// `language`, and `file` (file must be last per the docs).
///
/// Auth mirrors Grok chat: the OAuth token a SuperGrok / X Premium sign-in
/// produces is a plain bearer for `api.x.ai`, so it goes in the same header a
/// console key would. xAI does not document which surfaces a subscription
/// token reaches, and tier-gated accounts are reported to 403 on some of them,
/// so a rejected subscription retries with the API key when there is one
/// rather than failing the recording.
public struct XaiTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "XaiTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        /// A SuperGrok / X Premium OAuth access token, when the user has signed
        /// in to the Grok AI provider. Tried ahead of ``apiKey``; nil when there
        /// is no subscription to spend.
        public let subscriptionToken: String?
        /// One of xAI's 24 documented codes (e.g. "en", "fil"), or nil to let
        /// xAI detect the language. xAI rejects `format=true` without a concrete
        /// `language`, so nil drops both fields: losing Inverse Text
        /// Normalization is a better trade than forcing English onto a dictation
        /// in some other language.
        public let language: String?
        /// When true the API returns naturally formatted text with Inverse
        /// Text Normalization (e.g. "$100" instead of "one hundred dollars").
        public let formatted: Bool
        public let isSpeakerDiarizationEnabled: Bool

        public init(
            apiKey: String,
            subscriptionToken: String? = nil,
            language: String?,
            formatted: Bool = true,
            isSpeakerDiarizationEnabled: Bool = false
        ) {
            self.apiKey = apiKey
            self.subscriptionToken = subscriptionToken
            self.language = language
            self.formatted = formatted
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "XaiTranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        let subscriptionToken = config.subscriptionToken.flatMap { $0.isEmpty ? nil : $0 }

        guard subscriptionToken != nil || !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }

        if let subscriptionToken {
            do {
                return try await send(audioURL: audioURL, bearer: subscriptionToken)
            } catch let error as CloudTranscriptionError
                where !config.apiKey.isEmpty && Self.isCredentialRejection(error) {
                logger.logWarning("Grok subscription rejected for STT, falling back to the API key: \(error.localizedDescription)")
            }
        }

        return try await send(audioURL: audioURL, bearer: config.apiKey)
    }

    private func send(audioURL: URL, bearer: String) async throws -> TranscriptionServiceResult {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL, bearer: bearer)
        }
    }

    /// True when xAI turned the credential down, as opposed to rejecting the
    /// request itself - only the former is worth retrying with the other one.
    private static func isCredentialRejection(_ error: CloudTranscriptionError) -> Bool {
        switch error {
        case .invalidAPIKey: true
        case .apiRequestFailed(let statusCode, _): statusCode == 401 || statusCode == 403
        default: false
        }
    }

    private func makeTranscriptionRequest(audioURL: URL, bearer: String) async throws -> TranscriptionServiceResult {
        let apiURL = URL(string: "https://api.x.ai/v1/stt")!

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, boundary: boundary)

        let data: Data
        do {
            (data, _) = try await networkService.upload(request, from: body)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)

            if config.isSpeakerDiarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: transcriptionResponse.words) {
                return .speakerAttributed(diarizedText)
            }

            return .plain(transcriptionResponse.text)
        } catch {
            logger.logError("Failed to decode xAI STT response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createRequestBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        if let language = config.language {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"format\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append((config.formatted ? "true" : "false").data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)

            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(language.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        if config.isSpeakerDiarizationEnabled {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"diarize\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("true".data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        // `file` must be the last field per xAI docs.
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(audioURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    /// xAI reports a 0-based integer `speaker` per word (only when `diarize=true`)
    /// and, unlike ElevenLabs, emits no spacing tokens - so words in a turn are
    /// re-joined with single spaces and `SpeakerDiarizationFormatter` normalizes
    /// the result.
    private func makeSpeakerAttributedText(from words: [TranscriptionResponse.Word]?) -> String? {
        guard let words, !words.isEmpty else {
            return nil
        }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: Int?
        var currentWords: [String] = []

        for word in words {
            let wordSpeaker = word.speaker
            if turns.isEmpty && currentWords.isEmpty {
                currentSpeaker = wordSpeaker
                currentWords = [word.text]
                continue
            }

            if wordSpeaker == currentSpeaker || wordSpeaker == nil {
                currentWords.append(word.text)
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker.map(String.init), text: currentWords.joined(separator: " ")))
                currentSpeaker = wordSpeaker
                currentWords = [word.text]
            }
        }

        if !currentWords.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker.map(String.init), text: currentWords.joined(separator: " ")))
        }

        return SpeakerDiarizationFormatter.format(turns)
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let words: [Word]?

        struct Word: Decodable {
            let text: String
            let speaker: Int?
        }
    }
}
