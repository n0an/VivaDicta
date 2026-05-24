// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured Deepgram STT client. The router maps the `nova-3-multilingual`
/// alias to `(modelName: "nova-3", language: "multi")` before constructing the
/// config; this service treats both as opaque values.
public struct DeepgramTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "DeepgramTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        /// `"auto"` or BCP-47 (or `"multi"` for Nova-3 multilingual).
        public let language: String
        /// Caller should cap this list to ~100 terms.
        public let vocabulary: [String]
        public let isSpeakerDiarizationEnabled: Bool

        public init(apiKey: String, modelName: String, language: String = "auto", vocabulary: [String] = [], isSpeakerDiarizationEnabled: Bool = false) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.vocabulary = vocabulary
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    private let config: Config
    private let urlSession: any URLSessionProtocol

    public init(config: Config, urlSession: any URLSessionProtocol = URLSession.shared) {
        self.config = config
        self.urlSession = urlSession
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

        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "model", value: config.modelName)]

        queryItems.append(contentsOf: [
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "paragraphs", value: "true")
        ])

        if config.isSpeakerDiarizationEnabled {
            queryItems.append(URLQueryItem(name: "diarize", value: "true"))
            queryItems.append(URLQueryItem(name: "utterances", value: "true"))
        }

        if config.language != "auto", !config.language.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: config.language))
        }

        // Nova-3 models use keyterm prompting, while earlier Nova models use keywords.
        if !config.vocabulary.isEmpty {
            let paramName = config.modelName.hasPrefix("nova-3") ? "keyterm" : "keywords"
            for term in config.vocabulary {
                queryItems.append(URLQueryItem(name: paramName, value: term))
            }
            logger.logInfo("Adding \(config.vocabulary.count) custom vocabulary terms to Deepgram request")
        }

        components.queryItems = queryItems

        guard let apiURL = components.url else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Token \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(audioURL.audioMIMEType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let (data, response) = try await urlSession.upload(for: request, from: audioData)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Deepgram API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let transcript = transcriptionResponse.results.channels.first?.alternatives.first?.transcript,
                  !transcript.isEmpty else {
                logger.logError("No transcript found in Deepgram response")
                throw CloudTranscriptionError.noTranscriptionReturned
            }

            if config.isSpeakerDiarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: transcriptionResponse) {
                return .speakerAttributed(diarizedText)
            }

            return .plain(transcript)
        } catch let error as CloudTranscriptionError {
            throw error
        } catch {
            logger.logError("Failed to decode Deepgram API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func makeSpeakerAttributedText(from response: DeepgramResponse) -> String? {
        let turns = response.results.utterances?.map {
            SpeakerTurn(speakerID: $0.speaker.map(String.init), text: $0.transcript)
        } ?? []

        return SpeakerDiarizationFormatter.format(turns)
    }

    private struct DeepgramResponse: Decodable {
        let results: Results

        struct Results: Decodable {
            let channels: [Channel]
            let utterances: [Utterance]?

            struct Channel: Decodable {
                let alternatives: [Alternative]

                struct Alternative: Decodable {
                    let transcript: String
                    let confidence: Double?
                }
            }

            struct Utterance: Decodable {
                let speaker: Int?
                let transcript: String
            }
        }
    }
}
