//
//  GladiaTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.29
//

import Foundation
import os

struct GladiaTranscriptionService {
    private let logger = Logger(category: .gladiaTranscriptionService)
    private let apiBase = "https://api.gladia.io/v2"
    private let maxWaitSeconds: TimeInterval = 300
    private let pollIntervalNanoseconds: UInt64 = 1_000_000_000

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let config = try getAPIConfig(for: model)
        let diarizationEnabled = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled
        let translationTarget = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kTranslationTargetLanguageKey) ?? ""
        let translationEnabled = !translationTarget.isEmpty

        let uploadedURL = try await uploadFile(audioURL: audioURL, apiKey: config.apiKey)
        let jobId = try await createTranscription(
            audioURL: uploadedURL,
            apiKey: config.apiKey,
            diarizationEnabled: diarizationEnabled,
            translationTarget: translationTarget
        )
        let result = try await pollTranscription(
            id: jobId,
            apiKey: config.apiKey,
            diarizationEnabled: diarizationEnabled,
            translationEnabled: translationEnabled
        )

        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return result
    }

    // MARK: - Private Methods

    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let cloudModel = model as? CloudModel,
              let apiKey = cloudModel.apiKey,
              !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        return APIConfig(apiKey: apiKey)
    }

    private func uploadFile(audioURL: URL, apiKey: String) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/upload") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-gladia-key")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try createMultipartBody(fileURL: audioURL, boundary: boundary)
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Gladia upload failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            logger.logInfo("Gladia file uploaded, audio_url length: \(uploadResponse.audio_url.count)")
            return uploadResponse.audio_url
        } catch {
            logger.logError("Failed to decode Gladia upload response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createTranscription(
        audioURL: String,
        apiKey: String,
        diarizationEnabled: Bool,
        translationTarget: String
    ) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/pre-recorded") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-gladia-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "audio_url": audioURL,
            "diarization": diarizationEnabled
        ]

        // Language hints / auto-detect.
        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
        if selectedLanguage != "auto", !selectedLanguage.isEmpty {
            payload["language_config"] = [
                "languages": [selectedLanguage],
                "code_switching": false
            ]
        } else {
            payload["language_config"] = [
                "languages": [],
                "code_switching": true
            ]
        }

        // Inline translation.
        if !translationTarget.isEmpty {
            payload["translation"] = true
            payload["translation_config"] = [
                "target_languages": [translationTarget],
                "model": "enhanced",
                "match_original_utterances": true
            ]
            logger.logInfo("Gladia translation enabled, target: \(translationTarget)")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Gladia create transcription failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let createResponse = try JSONDecoder().decode(CreateTranscriptionResponse.self, from: data)
            logger.logInfo("Gladia transcription job created with ID: \(createResponse.id)")
            return createResponse.id
        } catch {
            logger.logError("Failed to decode Gladia create response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func pollTranscription(
        id: String,
        apiKey: String,
        diarizationEnabled: Bool,
        translationEnabled: Bool
    ) async throws -> TranscriptionServiceResult {
        guard let baseURL = URL(string: "\(apiBase)/pre-recorded/\(id)") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        let start = Date()

        while true {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = NetworkRetry.defaultTimeout
            request.setValue(apiKey, forHTTPHeaderField: "x-gladia-key")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
                logger.logError("Gladia status poll failed with status \(httpResponse.statusCode): \(errorMessage)")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            if let status = try? JSONDecoder().decode(StatusResponse.self, from: data) {
                switch status.status.lowercased() {
                case "done":
                    return try extractResult(
                        from: data,
                        diarizationEnabled: diarizationEnabled,
                        translationEnabled: translationEnabled
                    )
                case "error":
                    let errorCode = status.error_code ?? -1
                    logger.logError("Gladia job failed with error_code \(errorCode)")
                    throw CloudTranscriptionError.apiRequestFailed(statusCode: errorCode, message: "Transcription failed")
                default:
                    break
                }
            }

            if Date().timeIntervalSince(start) > maxWaitSeconds {
                logger.logError("Gladia transcription timed out after \(maxWaitSeconds) seconds")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: 504, message: "Transcription timed out")
            }

            try Task.checkCancellation()
            try await Task.sleep(for: .nanoseconds(pollIntervalNanoseconds))
        }
    }

    private func extractResult(
        from data: Data,
        diarizationEnabled: Bool,
        translationEnabled: Bool
    ) throws -> TranscriptionServiceResult {
        let decoded = try JSONDecoder().decode(JobResponse.self, from: data)

        guard let result = decoded.result else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }

        // When translation is enabled, prefer the translated transcript and utterances.
        if translationEnabled,
           let translation = result.translation,
           let firstResult = translation.results?.first {
            if diarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: firstResult.utterances) {
                return .speakerAttributed(diarizedText)
            }
            return .plain(firstResult.full_transcript)
        }

        // Fall back to the original transcription.
        if diarizationEnabled,
           let diarizedText = makeSpeakerAttributedText(from: result.transcription.utterances) {
            return .speakerAttributed(diarizedText)
        }
        return .plain(result.transcription.full_transcript)
    }

    private func makeSpeakerAttributedText(from utterances: [JobResponse.Utterance]?) -> String? {
        guard let utterances, !utterances.isEmpty else {
            return nil
        }

        // Gladia returns one speaker per utterance, so each utterance is its own turn.
        // Merge consecutive utterances from the same speaker into a single turn.
        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for utterance in utterances {
            let speakerID = utterance.speaker.map(String.init)

            if turns.isEmpty && currentText.isEmpty {
                currentSpeaker = speakerID
                currentText = utterance.text
                continue
            }

            if speakerID == currentSpeaker {
                currentText += " " + utterance.text
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = speakerID
                currentText = utterance.text
            }
        }

        if !currentText.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
        }

        return SpeakerDiarizationFormatter.format(turns)
    }

    private func createMultipartBody(fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: fileURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(fileURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    // MARK: - Response Types

    private struct APIConfig {
        let apiKey: String
    }

    private struct UploadResponse: Decodable {
        let audio_url: String
    }

    private struct CreateTranscriptionResponse: Decodable {
        let id: String
        let result_url: String?
    }

    private struct StatusResponse: Decodable {
        let status: String
        let error_code: Int?
    }

    private struct JobResponse: Decodable {
        let id: String
        let status: String
        let result: JobResult?

        struct JobResult: Decodable {
            let transcription: Transcription
            let translation: Translation?
        }

        struct Transcription: Decodable {
            let full_transcript: String
            let utterances: [Utterance]?
        }

        struct Translation: Decodable {
            let success: Bool?
            let results: [TranslationResult]?
        }

        struct TranslationResult: Decodable {
            let full_transcript: String
            let utterances: [Utterance]?
        }

        struct Utterance: Decodable {
            let text: String
            let speaker: Int?
            let language: String?
        }
    }
}
