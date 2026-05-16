// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os
import TranscriptionCore

/// Pre-configured Mistral STT client.
public struct MistralTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "MistralTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        public let language: String
        public let isSpeakerDiarizationEnabled: Bool

        public init(apiKey: String, modelName: String, language: String = "auto", isSpeakerDiarizationEnabled: Bool = false) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    public static func requestLanguage(for selectedLanguage: String, diarizationEnabled: Bool) -> String? {
        let normalizedLanguage = selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedLanguage.isEmpty == false, normalizedLanguage != "auto" else {
            return nil
        }

        // Mistral diarization requires automatic language detection.
        guard diarizationEnabled == false else {
            return nil
        }

        return normalizedLanguage
    }

    private let config: Config

    public init(config: Config) {
        self.config = config
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
        let apiURL = URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Mistral API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)

            if config.isSpeakerDiarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: transcriptionResponse) {
                return .speakerAttributed(diarizedText)
            }

            return .plain(transcriptionResponse.text)
        } catch {
            logger.logError("Failed to decode Mistral API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createRequestBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(config.modelName.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(audioURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        let requestLanguage = Self.requestLanguage(
            for: config.language,
            diarizationEnabled: config.isSpeakerDiarizationEnabled
        )

        if let requestLanguage {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(requestLanguage.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
            logger.logInfo("Using language: \(requestLanguage)")
        } else if config.isSpeakerDiarizationEnabled,
                  config.language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  config.language != "auto" {
            logger.logNotice("Skipping explicit language because Mistral diarization requires automatic language detection")
        }

        if config.isSpeakerDiarizationEnabled {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"diarize\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("true".data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)

            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"timestamp_granularities\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("segment".data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private func makeSpeakerAttributedText(from response: TranscriptionResponse) -> String? {
        let turns = response.segments?.map {
            SpeakerTurn(speakerID: $0.speakerID, text: $0.text)
        } ?? []

        return SpeakerDiarizationFormatter.format(turns)
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let segments: [TranscriptionSegment]?
    }

    private struct TranscriptionSegment: Decodable {
        let text: String
        let speakerID: String?

        private enum CodingKeys: String, CodingKey {
            case text
            case speakerID = "speaker_id"
        }
    }
}
