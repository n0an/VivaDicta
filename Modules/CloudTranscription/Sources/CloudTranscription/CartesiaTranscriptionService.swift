// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured Cartesia STT client. The app target is responsible for
/// normalizing `language` to a Cartesia-supported code before constructing
/// the config (Cartesia has no `"auto"`).
public struct CartesiaTranscriptionService: TranscriptionService, Sendable {
    /// Cartesia requires a date-formatted version header. Bumping this is a
    /// deliberate API-version pin; check the changelog before changing.
    public static let cartesiaVersion = "2026-03-01"

    private let apiURL = URL(string: "https://api.cartesia.ai/stt")!
    private let logger = Logger(cloudTranscriptionCategory: "CartesiaTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        /// Pre-normalized language code. Cartesia falls back to `"en"` when
        /// the picker yields `"auto"` or an unsupported code.
        public let language: String

        public init(apiKey: String, modelName: String, language: String) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
        }
    }

    private let config: Config
    private let urlSession: any URLSessionProtocol

    public init(config: Config, urlSession: any URLSessionProtocol = URLSession.shared) {
        self.config = config
        self.urlSession = urlSession
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

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.cartesiaVersion, forHTTPHeaderField: "Cartesia-Version")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, boundary: boundary)

        let (data, response) = try await urlSession.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Cartesia API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return transcriptionResponse.text
        } catch {
            logger.logError("Failed to decode Cartesia API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createRequestBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        logger.logInfo("Using language: \(config.language)")

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(config.modelName.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(config.language.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

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
