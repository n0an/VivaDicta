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
public struct XaiTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "XaiTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        /// One of xAI's 24 documented codes (e.g. "en", "fil"). xAI rejects
        /// `format=true` without a `language`, so no default is provided -
        /// callers must pass a concrete code (or pre-normalize "auto" → "en").
        public let language: String
        /// When true the API returns naturally formatted text with Inverse
        /// Text Normalization (e.g. "$100" instead of "one hundred dollars").
        public let formatted: Bool

        public init(apiKey: String, language: String, formatted: Bool = true) {
            self.apiKey = apiKey
            self.language = language
            self.formatted = formatted
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
        let text = try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL)
        }
        return .plain(text)
    }

    private func makeTranscriptionRequest(audioURL: URL) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        let apiURL = URL(string: "https://api.x.ai/v1/stt")!

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
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
            return transcriptionResponse.text
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

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"format\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append((config.formatted ? "true" : "false").data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(config.language.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // `file` must be the last field per xAI docs.
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(audioURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
    }
}
