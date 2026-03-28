// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

struct CohereTranscriptionService {
    private let logger = Logger(category: .cohereTranscriptionService)

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL, model: model)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        let config = try getAPIConfig(for: model)

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: config.url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(audioURL: audioURL, modelName: config.modelName, boundary: boundary)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Cohere API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return transcriptionResponse.text
        } catch {
            logger.logError("Failed to decode Cohere API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let cloudModel = model as? CloudModel,
              let apiKey = cloudModel.apiKey,
              !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }

        let apiURL = URL(string: "https://api.cohere.com/v2/audio/transcriptions")!
        return APIConfig(url: apiURL, apiKey: apiKey, modelName: model.name)
    }

    private func createRequestBody(audioURL: URL, modelName: String, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"

        // Cohere requires a language — default to English if auto or empty
        let language: String
        if selectedLanguage == "auto" || selectedLanguage.isEmpty {
            language = "en"
        } else {
            language = selectedLanguage
        }

        // Model (must appear before file)
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(modelName.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // Language (must appear before file, required by Cohere)
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(language.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // Temperature (must appear before file)
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append("0".data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // File (must be last)
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
    }
}
