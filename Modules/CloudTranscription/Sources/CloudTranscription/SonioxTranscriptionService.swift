// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os
import TranscriptionCore

/// Pre-configured Soniox STT client. Uses an upload + create + poll flow.
public struct SonioxTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "SonioxTranscription")
    private let apiBase = "https://api.soniox.com/v1"
    private let maxWaitSeconds: TimeInterval = 300
    private let pollIntervalNanoseconds: UInt64 = 1_000_000_000

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        public let language: String
        public let vocabulary: [String]
        public let isSpeakerDiarizationEnabled: Bool
        /// `""` = no translation requested.
        public let translationTargetLanguage: String

        public init(
            apiKey: String,
            modelName: String,
            language: String = "auto",
            vocabulary: [String] = [],
            isSpeakerDiarizationEnabled: Bool = false,
            translationTargetLanguage: String = ""
        ) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.vocabulary = vocabulary
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
            self.translationTargetLanguage = translationTargetLanguage
        }
    }

    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        let translationEnabled = !config.translationTargetLanguage.isEmpty

        let fileId = try await uploadFile(audioURL: audioURL)
        let transcriptionId = try await createTranscription(fileId: fileId)
        try await pollTranscriptionStatus(id: transcriptionId)
        let result = try await fetchTranscript(id: transcriptionId, translationEnabled: translationEnabled)

        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return result
    }

    private func uploadFile(audioURL: URL) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/files") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try createMultipartBody(fileURL: audioURL, boundary: boundary)
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Soniox file upload failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let uploadResponse = try JSONDecoder().decode(FileUploadResponse.self, from: data)
            logger.logInfo("File uploaded successfully with ID: \(uploadResponse.id)")
            return uploadResponse.id
        } catch {
            logger.logError("Failed to decode Soniox upload response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createTranscription(fileId: String) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/transcriptions") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "file_id": fileId,
            "model": config.modelName,
            "enable_speaker_diarization": config.isSpeakerDiarizationEnabled,
            "enable_language_identification": true
        ]

        if !config.vocabulary.isEmpty {
            payload["context"] = ["terms": config.vocabulary]
            logger.logInfo("Adding \(config.vocabulary.count) custom vocabulary terms")
        }

        if config.language != "auto", !config.language.isEmpty {
            payload["language_hints"] = [config.language]
            payload["language_hints_strict"] = true
        }

        if !config.translationTargetLanguage.isEmpty {
            payload["translation"] = [
                "type": "one_way",
                "target_language": config.translationTargetLanguage
            ]
            logger.logInfo("Soniox translation enabled, target: \(config.translationTargetLanguage)")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Soniox create transcription failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let createResponse = try JSONDecoder().decode(CreateTranscriptionResponse.self, from: data)
            logger.logInfo("Transcription job created with ID: \(createResponse.id)")
            return createResponse.id
        } catch {
            logger.logError("Failed to decode Soniox create response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func pollTranscriptionStatus(id: String) async throws {
        guard let baseURL = URL(string: "\(apiBase)/transcriptions/\(id)") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        let start = Date()

        while true {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = NetworkRetry.defaultTimeout
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
                logger.logError("Soniox status poll failed with status \(httpResponse.statusCode): \(errorMessage)")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            if let status = try? JSONDecoder().decode(TranscriptionStatusResponse.self, from: data) {
                switch status.status.lowercased() {
                case "completed":
                    logger.logInfo("Transcription completed")
                    return
                case "failed":
                    logger.logError("Transcription job failed")
                    throw CloudTranscriptionError.apiRequestFailed(statusCode: 500, message: "Transcription failed")
                default:
                    break
                }
            }

            if Date().timeIntervalSince(start) > maxWaitSeconds {
                logger.logError("Transcription timed out after \(maxWaitSeconds) seconds")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: 504, message: "Transcription timed out")
            }

            try Task.checkCancellation()
            try await Task.sleep(for: .nanoseconds(pollIntervalNanoseconds))
        }
    }

    private func fetchTranscript(id: String, translationEnabled: Bool) async throws -> TranscriptionServiceResult {
        guard let apiURL = URL(string: "\(apiBase)/transcriptions/\(id)/transcript") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Soniox fetch transcript failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        if let decoded = try? JSONDecoder().decode(TranscriptResponse.self, from: data) {
            let effectiveTokens = translationEnabled
                ? (decoded.tokens?.filter { $0.translationStatus == "translation" })
                : decoded.tokens

            if config.isSpeakerDiarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: effectiveTokens) {
                return .speakerAttributed(diarizedText)
            }

            if translationEnabled {
                let translatedText = (effectiveTokens ?? []).map(\.text).joined()
                return .plain(translatedText)
            }
            return .plain(decoded.text)
        }

        if let asString = String(data: data, encoding: .utf8), !asString.isEmpty {
            return .plain(asString)
        }

        throw CloudTranscriptionError.noTranscriptionReturned
    }

    private func makeSpeakerAttributedText(from tokens: [TranscriptResponse.Token]?) -> String? {
        guard let tokens, !tokens.isEmpty else {
            return nil
        }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for token in tokens {
            let tokenSpeaker = token.speaker
            if turns.isEmpty && currentText.isEmpty {
                currentSpeaker = tokenSpeaker
                currentText = token.text
                continue
            }

            if tokenSpeaker == currentSpeaker || tokenSpeaker == nil {
                currentText += token.text
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = tokenSpeaker
                currentText = token.text
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
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(fileURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private struct FileUploadResponse: Decodable {
        let id: String
    }

    private struct CreateTranscriptionResponse: Decodable {
        let id: String
    }

    private struct TranscriptionStatusResponse: Decodable {
        let status: String
    }

    private struct TranscriptResponse: Decodable {
        let text: String
        let tokens: [Token]?

        struct Token: Decodable {
            let text: String
            let speaker: String?
            let language: String?
            let translationStatus: String?

            enum CodingKeys: String, CodingKey {
                case text, speaker, language
                case translationStatus = "translation_status"
            }
        }
    }
}
