// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os
import TranscriptionCore

/// Pre-configured ElevenLabs speech-to-text client. Stateless apart from its
/// config; the app target builds one per request.
public struct ElevenLabsTranscriptionService: Sendable {
    private let apiURL = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    private let logger = Logger(cloudTranscriptionCategory: "ElevenLabsTranscription")

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        /// BCP-47 code, or `"auto"` to let ElevenLabs detect.
        public let language: String

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
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        logger.notice("ElevenLabs API Response Status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(ElevenLabsTranscriptionResponse.self, from: data)
            return transcriptionResponse.text
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

        if config.language != "auto", !config.language.isEmpty {
            body.append(formField: "language_code", value: config.language, boundary: boundary)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    private struct ElevenLabsTranscriptionResponse: Decodable {
        let text: String
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
