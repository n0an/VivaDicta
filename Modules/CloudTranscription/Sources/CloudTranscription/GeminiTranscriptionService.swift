// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured Google Gemini transcription client. Stateless apart from its
/// config; the app target builds one per request.
public struct GeminiTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "GeminiTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String

        public init(apiKey: String, modelName: String) {
            self.apiKey = apiKey
            self.modelName = modelName
        }
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "GeminiTranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        let text = try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL)
        }
        return .plain(text)
    }

    private func makeTranscriptionRequest(audioURL: URL) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(config.modelName):generateContent"
        guard let apiURL = URL(string: urlString) else {
            throw CloudTranscriptionError.dataEncodingError
        }

        logger.logNotice("Starting Gemini transcription with model: \(config.modelName)")

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        logger.logNotice("Audio file loaded, size: \(audioData.count) bytes")

        let base64AudioData = audioData.base64EncodedString()

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        .text(GeminiTextPart(text: "Please transcribe this audio file. Provide only the transcribed text.")),
                        .audio(GeminiAudioPart(
                            inlineData: GeminiInlineData(
                                mimeType: audioURL.audioMIMEType,
                                data: base64AudioData
                            )
                        ))
                    ]
                )
            ]
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            logger.logError("Failed to encode Gemini request: \(error.localizedDescription)")
            throw CloudTranscriptionError.dataEncodingError
        }

        let transcriptionResponse: GeminiResponse
        do {
            transcriptionResponse = try await networkService.sendJSON(request, as: GeminiResponse.self)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        guard let candidate = transcriptionResponse.candidates.first,
              let part = candidate.content.parts.first,
              !part.text.isEmpty else {
            logger.logError("No transcript found in Gemini response")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return part.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct GeminiRequest: Codable {
        let contents: [GeminiContent]
    }

    private struct GeminiContent: Codable {
        let parts: [GeminiPart]
    }

    private enum GeminiPart: Codable {
        case text(GeminiTextPart)
        case audio(GeminiAudioPart)

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let textPart):
                try container.encode(textPart)
            case .audio(let audioPart):
                try container.encode(audioPart)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let textPart = try? container.decode(GeminiTextPart.self) {
                self = .text(textPart)
            } else if let audioPart = try? container.decode(GeminiAudioPart.self) {
                self = .audio(audioPart)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid part"))
            }
        }
    }

    private struct GeminiTextPart: Codable {
        let text: String
    }

    private struct GeminiAudioPart: Codable {
        let inlineData: GeminiInlineData
    }

    private struct GeminiInlineData: Codable {
        let mimeType: String
        let data: String
    }

    // Response types are `internal` (not `private`) so consumer tests can
    // construct a decoded `GeminiResponse` to stub `NetworkService.sendJSON`,
    // which returns an already-decoded value rather than raw `Data`.
    struct GeminiResponse: Codable {
        let candidates: [GeminiCandidate]
    }

    struct GeminiCandidate: Codable {
        let content: GeminiResponseContent
    }

    struct GeminiResponseContent: Codable {
        let parts: [GeminiResponsePart]
    }

    struct GeminiResponsePart: Codable {
        let text: String
    }
}
