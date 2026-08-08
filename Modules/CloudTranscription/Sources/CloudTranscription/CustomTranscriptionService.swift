// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// User-configured OpenAI-compatible transcription endpoint. The endpoint URL,
/// optional API key, and model name come from the user's stored custom model;
/// the router builds the config from `CustomTranscriptionModel` at call time.
///
/// The body is sent as `multipart/form-data` by default and as JSON with a
/// base64 data URI when the config asks for it - see
/// `CustomTranscriptionRequestFormat`.
public struct CustomTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "CustomTranscription")

    public struct Config: Sendable {
        public let apiEndpoint: String
        public let apiKey: String?
        public let modelName: String
        /// `"auto"` or BCP-47.
        public let language: String
        /// Wire format the endpoint expects. See `CustomTranscriptionRequestFormat`.
        public let requestFormat: CustomTranscriptionRequestFormat

        public init(
            apiEndpoint: String,
            apiKey: String?,
            modelName: String,
            language: String = "auto",
            requestFormat: CustomTranscriptionRequestFormat = .multipartFormData
        ) {
            self.apiEndpoint = apiEndpoint
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.requestFormat = requestFormat
        }
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "CustomTranscription")
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
        guard let url = URL(string: config.apiEndpoint) else {
            throw CloudTranscriptionError.unsupportedProvider
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body: Data
        switch config.requestFormat {
        case .multipartFormData:
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            body = try createMultipartBody(audioURL: audioURL, boundary: boundary)

        case .jsonBase64:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            body = try createJSONBody(audioURL: audioURL)
        }

        logger.logInfo("Sending request to custom endpoint: \(config.apiEndpoint)")

        let data: Data
        do {
            (data, _) = try await networkService.upload(request, from: body)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            logger.logInfo("Transcription successful, received \(transcriptionResponse.text.count) characters")
            return transcriptionResponse.text
        } catch {
            logger.logError("Failed to decode API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    /// `nil` when the user left the language on auto-detect, so the field is
    /// dropped from the request instead of pinning the server to a language.
    private var explicitLanguage: String? {
        guard config.language != "auto", !config.language.isEmpty else { return nil }
        return config.language
    }

    private func createMultipartBody(audioURL: URL, boundary: String) throws -> Data {
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

        if let language = explicitLanguage {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(language.data(using: .utf8)!)
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

    /// Same fields as the multipart body, but as JSON with the audio inlined
    /// as a data URI - the shape gateways like Polza.ai expect.
    private func createJSONBody(audioURL: URL) throws -> Data {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let payload = JSONRequestBody(
            file: "data:\(audioURL.audioMIMEType);base64,\(audioData.base64EncodedString())",
            model: config.modelName,
            language: explicitLanguage,
            responseFormat: "json",
            temperature: 0
        )

        do {
            return try JSONEncoder().encode(payload)
        } catch {
            logger.logError("Failed to encode JSON request body: \(error.localizedDescription)")
            throw CloudTranscriptionError.dataEncodingError
        }
    }

    private struct JSONRequestBody: Encodable {
        let file: String
        let model: String
        /// Omitted entirely when nil, matching the multipart body.
        let language: String?
        let responseFormat: String
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case file, model, language, temperature
            case responseFormat = "response_format"
        }
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let duration: Double?
    }
}
