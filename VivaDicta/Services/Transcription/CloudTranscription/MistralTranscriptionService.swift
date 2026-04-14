//
//  MistralTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.07
//

import Foundation
import os

struct MistralTranscriptionService {
    private let logger = Logger(category: .mistralTranscriptionService)

    static func requestLanguage(for selectedLanguage: String, diarizationEnabled: Bool) -> String? {
        let normalizedLanguage = selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedLanguage.isEmpty == false, normalizedLanguage != "auto" else {
            return nil
        }

        guard diarizationEnabled == false else {
            return nil
        }

        return normalizedLanguage
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL, model: model)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let config = try getAPIConfig(for: model)
        let diarizationEnabled = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: config.url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let body = try createRequestBody(
            audioURL: audioURL,
            modelName: config.modelName,
            boundary: boundary,
            diarizationEnabled: diarizationEnabled
        )

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

            if diarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: transcriptionResponse) {
                return .speakerAttributed(diarizedText)
            }

            return .plain(transcriptionResponse.text)
        } catch {
            logger.logError("Failed to decode Mistral API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let cloudModel = model as? CloudModel,
              let apiKey = cloudModel.apiKey,
              !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }

        let apiURL = URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!
        return APIConfig(url: apiURL, apiKey: apiKey, modelName: model.name)
    }

    private func createRequestBody(
        audioURL: URL,
        modelName: String,
        boundary: String,
        diarizationEnabled: Bool
    ) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        // Add model field
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(modelName.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        // Add file data
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(audioURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        // Add language field if not auto-detect
        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
        let requestLanguage = Self.requestLanguage(
            for: selectedLanguage,
            diarizationEnabled: diarizationEnabled
        )

        if let requestLanguage {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(requestLanguage.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
            logger.logInfo("Using language: \(requestLanguage)")
        } else if diarizationEnabled,
                  selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  selectedLanguage != "auto" {
            logger.logNotice("Skipping explicit language because Mistral diarization requires automatic language detection")
        }

        if diarizationEnabled {
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
            SpeakerTurn(
                speakerID: $0.speakerID,
                text: $0.text
            )
        } ?? []

        return SpeakerDiarizationFormatter.format(turns)
    }

    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
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
