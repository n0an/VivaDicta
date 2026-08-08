// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
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
        public let isSpeakerDiarizationEnabled: Bool

        /// - Parameter language: BCP-47 language tag or `"auto"` to let OpenAI detect.
        public init(
            apiKey: String,
            modelName: String,
            language: String = "auto",
            isSpeakerDiarizationEnabled: Bool = false
        ) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    /// `gpt-4o-transcribe-diarize` takes a different parameter set: it requires
    /// `chunking_strategy` for audio over 30 seconds, returns speaker-labeled
    /// segments via the `diarized_json` response format, and does not accept
    /// `language`, `temperature`, or prompts.
    private var isDiarizeModel: Bool {
        config.modelName == "gpt-4o-transcribe-diarize"
    }

    /// `gpt-transcribe` replaced the singular `language` field with a repeated
    /// `languages[]` hint list (OpenAI rejects requests carrying both), and does
    /// not accept `temperature`.
    private var isGPTTranscribeModel: Bool {
        config.modelName == "gpt-transcribe"
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "OpenAITranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL) async throws -> TranscriptionServiceResult {
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

        let data: Data
        do {
            (data, _) = try await networkService.upload(request, from: body)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            if isDiarizeModel && config.isSpeakerDiarizationEnabled {
                let diarized = try JSONDecoder().decode(DiarizedTranscriptionResponse.self, from: data)
                if let diarizedText = makeSpeakerAttributedText(from: diarized.segments) {
                    return .speakerAttributed(diarizedText)
                }
                return .plain(diarized.segments.map(\.text).joined(separator: " "))
            }
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return .plain(transcriptionResponse.text)
        } catch {
            logger.logError("Failed to decode OpenAI API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func makeSpeakerAttributedText(from segments: [DiarizedTranscriptionResponse.Segment]) -> String? {
        guard !segments.isEmpty else {
            return nil
        }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for segment in segments {
            if turns.isEmpty && currentText.isEmpty {
                currentSpeaker = segment.speaker
                currentText = segment.text
                continue
            }

            if segment.speaker == currentSpeaker || segment.speaker == nil {
                currentText += " " + segment.text
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = segment.speaker
                currentText = segment.text
            }
        }

        if !currentText.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
        }

        return SpeakerDiarizationFormatter.format(turns)
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

        if !isDiarizeModel, config.language != "auto", !config.language.isEmpty {
            let languageField = isGPTTranscribeModel ? "languages[]" : "language"
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(languageField)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(config.language.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        let responseFormat = isDiarizeModel && config.isSpeakerDiarizationEnabled ? "diarized_json" : "json"
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(responseFormat.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)

        if isDiarizeModel {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"chunking_strategy\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("auto".data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        } else if !isGPTTranscribeModel {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"temperature\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("0".data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let duration: Double?
    }

    private struct DiarizedTranscriptionResponse: Decodable {
        let segments: [Segment]

        struct Segment: Decodable {
            let text: String
            let speaker: String?
        }
    }
}
