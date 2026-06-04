// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured ElevenLabs speech-to-text client. Stateless apart from its
/// config; the app target builds one per request.
public struct ElevenLabsTranscriptionService: TranscriptionService, Sendable {
    private let apiURL = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    private let logger = Logger(cloudTranscriptionCategory: "ElevenLabsTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        /// BCP-47 code, or `"auto"` to let ElevenLabs detect.
        public let language: String
        public let isSpeakerDiarizationEnabled: Bool

        public init(
            apiKey: String,
            modelName: String,
            language: String = "auto",
            isSpeakerDiarizationEnabled: Bool = false
        ) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "ElevenLabsTranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL) async throws -> TranscriptionServiceResult {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, boundary: boundary)

        let data: Data
        do {
            (data, _) = try await networkService.upload(request, from: body)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(ElevenLabsTranscriptionResponse.self, from: data)

            if config.isSpeakerDiarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: transcriptionResponse.words) {
                return .speakerAttributed(diarizedText)
            }

            return .plain(transcriptionResponse.text)
        } catch {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createRequestBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()

        body.append(formField: "file", fileName: audioURL.lastPathComponent, fileData: try Data(contentsOf: audioURL), mimeType: audioURL.audioMIMEType, boundary: boundary)
        body.append(formField: "model_id", value: config.modelName, boundary: boundary)
        body.append(formField: "temperature", value: "0.0", boundary: boundary)
        body.append(formField: "tag_audio_events", value: "false", boundary: boundary)

        if config.isSpeakerDiarizationEnabled {
            body.append(formField: "diarize", value: "true", boundary: boundary)
        }

        if config.language != "auto", !config.language.isEmpty {
            body.append(formField: "language_code", value: config.language, boundary: boundary)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    /// ElevenLabs reports speakers only at the word level (no segment grouping),
    /// so consecutive words sharing a `speaker_id` are merged into turns. The
    /// `words` array interleaves `spacing` entries whose `text` is a literal
    /// space, so concatenating `text` directly preserves word boundaries.
    private func makeSpeakerAttributedText(from words: [ElevenLabsTranscriptionResponse.Word]?) -> String? {
        guard let words, !words.isEmpty else {
            return nil
        }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for word in words {
            let wordSpeaker = word.speakerID
            if turns.isEmpty && currentText.isEmpty {
                currentSpeaker = wordSpeaker
                currentText = word.text
                continue
            }

            if wordSpeaker == currentSpeaker || wordSpeaker == nil {
                currentText += word.text
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = wordSpeaker
                currentText = word.text
            }
        }

        if !currentText.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
        }

        return SpeakerDiarizationFormatter.format(turns)
    }

    private struct ElevenLabsTranscriptionResponse: Decodable {
        let text: String
        let words: [Word]?

        struct Word: Decodable {
            let text: String
            let speakerID: String?

            enum CodingKeys: String, CodingKey {
                case text
                case speakerID = "speaker_id"
            }
        }
    }
}

private extension Data {
    mutating func append(formField: String, value: String, boundary: String) {
        let crlf = "\r\n"
        append("--\(boundary)\(crlf)".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(formField)\"\(crlf)\(crlf)".data(using: .utf8)!)
        append(value.data(using: .utf8)!)
        append(crlf.data(using: .utf8)!)
    }

    mutating func append(formField: String, fileName: String, fileData: Data, mimeType: String, boundary: String) {
        let crlf = "\r\n"
        append("--\(boundary)\(crlf)".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(formField)\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\(crlf)\(crlf)".data(using: .utf8)!)
        append(fileData)
        append(crlf.data(using: .utf8)!)
    }
}
