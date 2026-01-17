//
//  CustomTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import Foundation
import os

struct CustomTranscriptionService {
    private let logger = Logger(category: .customTranscriptionService)

    func transcribe(audioURL: URL, model: CustomTranscriptionModel) async throws -> String {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL, model: model)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL, model: CustomTranscriptionModel) async throws -> String {
        guard let url = URL(string: model.apiEndpoint) else {
            throw CloudTranscriptionError.unsupportedProvider
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // API key is optional - only add Authorization header if provided
        if let apiKey = model.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, modelName: model.modelName, boundary: boundary)

        logger.logInfo("Sending request to custom endpoint: \(model.apiEndpoint)")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Custom API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
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

    private func createRequestBody(audioURL: URL, modelName: String, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"

        // Audio file
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        // Model name
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(modelName.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // Language (if not auto)
        if selectedLanguage != "auto", !selectedLanguage.isEmpty {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(selectedLanguage.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        // Response format
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append("json".data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // Temperature
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
