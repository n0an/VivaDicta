// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os
import TranscriptionCore

/// Pre-configured OpenAI Whisper API client. Each instance is bound to a single
/// API key + model + language at construction; call `transcribe(audioURL:)` to
/// run the request. Stateless apart from its config, so it's safe to create per
/// transcription.
public struct OpenAITranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "OpenAITranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        public let language: String

        /// - Parameter language: BCP-47 language tag or `"auto"` to let OpenAI detect.
        public init(apiKey: String, modelName: String, language: String = "auto") {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
        }
    }

    private let config: Config

    public init(config: Config) {
        self.config = config
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
        let apiURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createOpenAICompatibleRequestBody(audioURL: audioURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("OpenAI API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return transcriptionResponse.text
        } catch {
            logger.logError("Failed to decode OpenAI API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createOpenAICompatibleRequestBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(audioURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(config.modelName.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        if config.language != "auto", !config.language.isEmpty {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(config.language.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append("json".data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append("0".data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let duration: Double?
    }
}
