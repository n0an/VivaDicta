// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured AssemblyAI STT client. Uses an upload + create + poll flow:
/// the raw audio is uploaded to `/v2/upload` to obtain a hosted `upload_url`,
/// a transcript job is created via `/v2/transcript`, then the job is polled
/// until it reports `completed`. AssemblyAI authenticates with the raw API key
/// in the `Authorization` header (no `Bearer` prefix).
public struct AssemblyAITranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "AssemblyAITranscription")
    private let apiBase = "https://api.assemblyai.com/v2"
    private let maxWaitSeconds: TimeInterval = 300
    private let pollIntervalNanoseconds: UInt64 = 3_000_000_000

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        public let language: String
        public let vocabulary: [String]
        public let isSpeakerDiarizationEnabled: Bool

        public init(
            apiKey: String,
            modelName: String = "universal-3-pro",
            language: String = "auto",
            vocabulary: [String] = [],
            isSpeakerDiarizationEnabled: Bool = false
        ) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.vocabulary = vocabulary
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "AssemblyAITranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }

        let uploadedURL = try await uploadFile(audioURL: audioURL)
        let transcriptId = try await createTranscript(audioURL: uploadedURL)
        let result = try await pollTranscript(id: transcriptId)

        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return result
    }

    /// Uploads the raw audio bytes and returns the hosted `upload_url`.
    private func uploadFile(audioURL: URL) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/upload") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue(config.apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let data: Data
        do {
            (data, _) = try await networkService.upload(request, from: audioData)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            logger.logInfo("AssemblyAI file uploaded")
            return uploadResponse.upload_url
        } catch {
            logger.logError("Failed to decode AssemblyAI upload response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func createTranscript(audioURL: String) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/transcript") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue(config.apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let models = config.modelName.isEmpty ? ["universal-3-pro"] : [config.modelName]

        var payload: [String: Any] = [
            "audio_url": audioURL,
            // `speech_models` is required and has no default. The list is a
            // priority order; we send the user's selected model.
            "speech_models": models
        ]

        // AssemblyAI takes either a concrete `language_code` or `language_detection`.
        if config.language == "auto" || config.language.isEmpty {
            payload["language_detection"] = true
        } else {
            payload["language_code"] = config.language
        }

        if config.isSpeakerDiarizationEnabled {
            payload["speaker_labels"] = true
        }

        // `word_boost` is AssemblyAI's custom-vocabulary mechanism.
        if !config.vocabulary.isEmpty {
            payload["word_boost"] = config.vocabulary
            logger.logInfo("Adding \(config.vocabulary.count) custom vocabulary terms to AssemblyAI request")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        do {
            (data, _) = try await networkService.send(request)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            let createResponse = try JSONDecoder().decode(CreateTranscriptResponse.self, from: data)
            logger.logInfo("AssemblyAI transcript created with ID: \(createResponse.id)")
            return createResponse.id
        } catch {
            logger.logError("Failed to decode AssemblyAI create response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func pollTranscript(id: String) async throws -> TranscriptionServiceResult {
        guard let baseURL = URL(string: "\(apiBase)/transcript/\(id)") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        let start = Date()

        while true {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = NetworkRetry.defaultTimeout
            request.setValue(config.apiKey, forHTTPHeaderField: "Authorization")

            let data: Data
            do {
                (data, _) = try await networkService.send(request)
            } catch let error as NetworkError {
                throw error.asTranscriptionError()
            }

            if let status = try? JSONDecoder().decode(StatusResponse.self, from: data) {
                switch status.status.lowercased() {
                case "completed":
                    logger.logInfo("AssemblyAI transcription completed")
                    return try extractResult(from: data)
                case "error":
                    logger.logError("AssemblyAI transcription failed: \(status.error ?? "Unknown error")")
                    throw CloudTranscriptionError.apiRequestFailed(statusCode: 500, message: status.error ?? "Transcription failed")
                default:
                    break
                }
            }

            if Date().timeIntervalSince(start) > maxWaitSeconds {
                logger.logError("AssemblyAI transcription timed out after \(maxWaitSeconds) seconds")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: 504, message: "Transcription timed out")
            }

            try await Task.sleep(for: .nanoseconds(pollIntervalNanoseconds))
        }
    }

    private func extractResult(from data: Data) throws -> TranscriptionServiceResult {
        guard let decoded = try? JSONDecoder().decode(TranscriptResponse.self, from: data) else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }

        if config.isSpeakerDiarizationEnabled,
           let diarizedText = makeSpeakerAttributedText(from: decoded.utterances) {
            return .speakerAttributed(diarizedText)
        }

        return .plain(decoded.text ?? "")
    }

    private func makeSpeakerAttributedText(from utterances: [TranscriptResponse.Utterance]?) -> String? {
        guard let utterances, !utterances.isEmpty else {
            return nil
        }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for utterance in utterances {
            let speaker = utterance.speaker

            if turns.isEmpty && currentText.isEmpty {
                currentSpeaker = speaker
                currentText = utterance.text
                continue
            }

            if speaker == currentSpeaker || speaker == nil {
                currentText += " " + utterance.text
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = speaker
                currentText = utterance.text
            }
        }

        if !currentText.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
        }

        return SpeakerDiarizationFormatter.format(turns)
    }

    private struct UploadResponse: Decodable {
        let upload_url: String
    }

    private struct CreateTranscriptResponse: Decodable {
        let id: String
    }

    private struct StatusResponse: Decodable {
        let status: String
        let error: String?
    }

    private struct TranscriptResponse: Decodable {
        let text: String?
        let utterances: [Utterance]?

        struct Utterance: Decodable {
            let text: String
            let speaker: String?
        }
    }
}
