// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured Google Gemini transcription client. Stateless apart from its
/// config; the app target builds one per request.
public struct GeminiTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "GeminiTranscription")

    /// Gemini's dedicated speech-to-text models, served by the Interactions API.
    ///
    /// These are not general-purpose models that happen to accept audio, and
    /// they are not reachable the same way. `generateContent` answers for them
    /// with HTTP 200, `finishReason: STOP`, an empty content part and zero
    /// output tokens - it bills the audio and returns nothing - so a shared
    /// request path would look like a working integration that never
    /// transcribes. Verified 2026-08-27 across both API versions, every content
    /// arrangement, and three MIME types.
    ///
    /// They also reject two fields the `generateContent` path sends:
    /// `thinkingConfig` ("Thinking level is not supported for this model") and
    /// `systemInstruction` ("Developer instruction is not enabled for this
    /// model").
    public static let transcribeModels: Set<String> = ["gemini-3.5-transcribe"]

    /// The subset that can attribute speech to speakers.
    public static let diarizingModels: Set<String> = ["gemini-3.5-transcribe"]

    /// The instruction sent alongside the audio on the `generateContent` path,
    /// used whenever the user has not written their own.
    public static let defaultTranscriptionPrompt = "Please transcribe this audio file. Provide only the transcribed text."

    /// How much the general-purpose models are allowed to reason before
    /// answering.
    ///
    /// Gemini 3.x Flash defaults to thinking on at medium, so every dictation
    /// bought a reasoning pass it had no use for. Measured 2026-08-27 on a
    /// 2m12s clip: 5.2s and 683 thought tokens by default, 2.8s and zero at
    /// "low" - which is why "low" stays the default.
    ///
    /// "minimal" is deliberately absent even though the 3.5/3.6 generation
    /// accepts it. `gemini-3.7-flash` answers it with a validation error, and
    /// this is one setting shared by every Gemini model, so an option that
    /// fails outright on the newest one is not worth offering.
    public enum ThinkingLevel: String, CaseIterable, Sendable, Codable {
        case low
        case medium
        case high
    }

    public struct Config: Sendable {
        public let apiKey: String
        public let modelName: String
        /// `"auto"` or BCP-47. Only the Interactions API models accept it.
        public let language: String
        /// Only the Interactions API models accept it; capped at 1,000 terms.
        public let vocabulary: [String]
        public let isSpeakerDiarizationEnabled: Bool
        /// Only the `generateContent` models accept it - the dedicated
        /// transcription models reject `thinkingConfig` outright.
        public let thinkingLevel: ThinkingLevel
        /// The instruction sent with the audio. Only the `generateContent`
        /// models are prompted at all; blank falls back to
        /// ``defaultTranscriptionPrompt``.
        public let prompt: String

        public init(
            apiKey: String,
            modelName: String,
            language: String = "auto",
            vocabulary: [String] = [],
            isSpeakerDiarizationEnabled: Bool = false,
            thinkingLevel: ThinkingLevel = .low,
            prompt: String = GeminiTranscriptionService.defaultTranscriptionPrompt
        ) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.language = language
            self.vocabulary = vocabulary
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
            self.thinkingLevel = thinkingLevel
            self.prompt = prompt
        }

        /// The instruction actually sent, with a blank or whitespace-only
        /// custom prompt falling back to the default rather than asking the
        /// model to transcribe with no instruction at all.
        var resolvedPrompt: String {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? GeminiTranscriptionService.defaultTranscriptionPrompt : trimmed
        }
    }

    private let config: Config
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "GeminiTranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        if Self.transcribeModels.contains(config.modelName) {
            return try await NetworkRetry.withRetry(logger: logger) {
                try await makeInteractionsRequest(audioURL: audioURL)
            }
        }

        let text = try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL)
        }
        return .plain(text)
    }

    // MARK: - Interactions API (dedicated transcription models)

    private func makeInteractionsRequest(audioURL: URL) async throws -> TranscriptionServiceResult {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        guard let apiURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions") else {
            throw CloudTranscriptionError.dataEncodingError
        }
        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        logger.logNotice("Starting Gemini transcription with \(config.modelName) via the Interactions API, \(audioData.count) bytes")

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        let wantsSpeakers = config.isSpeakerDiarizationEnabled
            && Self.diarizingModels.contains(config.modelName)
        let hasExplicitLanguage = config.language != "auto" && !config.language.isEmpty

        let requestBody = InteractionsRequest(
            model: config.modelName,
            input: [
                InteractionsRequest.Input(
                    data: audioData.base64EncodedString(),
                    mimeType: audioURL.audioMIMEType
                )
            ],
            generationConfig: InteractionsRequest.GenerationConfig(
                transcriptionConfig: InteractionsRequest.TranscriptionConfig(
                    // An empty list is how the model is asked to detect the
                    // language, so a pinned one is sent only when explicit.
                    languageCodes: hasExplicitLanguage ? [config.language] : nil,
                    customVocabulary: config.vocabulary.isEmpty ? nil : Array(config.vocabulary.prefix(1000)),
                    mode: wantsSpeakers
                        // Speaker labels arrive as per-word annotations, and
                        // asking for `diarization_mode` alone returns none of
                        // them - the word granularity has to be requested with
                        // it. "smart" rejects both outright, so diarization
                        // means giving up the disfluency removal.
                        ? .init(type: "verbatim", diarizationMode: "speaker", timestampGranularities: ["word"])
                        // Otherwise "smart": it strips fillers and
                        // self-corrections and formats as it goes.
                        : .init(type: "smart", diarizationMode: nil, timestampGranularities: nil)
                )
            )
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            logger.logError("Failed to encode Gemini Interactions request: \(error.localizedDescription)")
            throw CloudTranscriptionError.dataEncodingError
        }

        let decoded: InteractionsResponse
        do {
            decoded = try await networkService.sendJSON(request, as: InteractionsResponse.self)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        if wantsSpeakers, let attributed = decoded.speakerAttributedText {
            logger.logNotice("Gemini transcription successful with speaker labels, length \(attributed.count)")
            return .speakerAttributed(attributed)
        }

        let text = decoded.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            logger.logError("No transcript found in Gemini Interactions response")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        logger.logNotice("Gemini transcription successful, text length: \(text.count)")
        return .plain(text)
    }

    private struct InteractionsRequest: Encodable {
        let model: String
        let input: [Input]
        let generationConfig: GenerationConfig

        enum CodingKeys: String, CodingKey {
            case model, input
            case generationConfig = "generation_config"
        }

        struct Input: Encodable {
            var type = "audio"
            let data: String
            let mimeType: String

            enum CodingKeys: String, CodingKey {
                case type, data
                case mimeType = "mime_type"
            }
        }

        struct GenerationConfig: Encodable {
            let transcriptionConfig: TranscriptionConfig

            enum CodingKeys: String, CodingKey {
                case transcriptionConfig = "transcription_config"
            }
        }

        struct TranscriptionConfig: Encodable {
            let languageCodes: [String]?
            let customVocabulary: [String]?
            let mode: Mode

            enum CodingKeys: String, CodingKey {
                case languageCodes = "language_codes"
                case customVocabulary = "custom_vocabulary"
                case mode
            }
        }

        struct Mode: Encodable {
            let type: String
            let diarizationMode: String?
            let timestampGranularities: [String]?

            enum CodingKeys: String, CodingKey {
                case type
                case diarizationMode = "diarization_mode"
                case timestampGranularities = "timestamp_granularities"
            }
        }
    }

    private struct InteractionsResponse: Decodable {
        let steps: [Step]?

        struct Step: Decodable {
            let content: [Content]?

            struct Content: Decodable {
                let type: String?
                let text: String?
                let annotations: [Annotation]?

                struct Annotation: Decodable {
                    let text: String?
                    let speaker: String?
                }
            }
        }

        private var textContents: [Step.Content] {
            (steps ?? []).flatMap { $0.content ?? [] }.filter { $0.type == "text" }
        }

        var plainText: String {
            textContents.compactMap(\.text).joined()
        }

        /// One `word_info` annotation per word, each carrying its own speaker,
        /// so words are grouped into turns wherever the speaker changes.
        var speakerAttributedText: String? {
            let words = textContents.flatMap { $0.annotations ?? [] }
            guard !words.isEmpty else { return nil }

            var turns: [SpeakerTurn] = []
            var currentSpeaker: String?
            var currentWords: [String] = []

            for word in words {
                guard let text = word.text, !text.isEmpty else { continue }

                if currentWords.isEmpty {
                    currentSpeaker = word.speaker
                    currentWords = [text]
                } else if word.speaker == currentSpeaker || word.speaker == nil {
                    currentWords.append(text)
                } else {
                    turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentWords.joined(separator: " ")))
                    currentSpeaker = word.speaker
                    currentWords = [text]
                }
            }

            if !currentWords.isEmpty {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentWords.joined(separator: " ")))
            }

            return SpeakerDiarizationFormatter.format(turns)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(config.modelName):generateContent"
        guard let apiURL = URL(string: urlString) else {
            throw CloudTranscriptionError.dataEncodingError
        }

        logger.logNotice("Starting Gemini transcription with model: \(config.modelName), thinking level: \(config.thinkingLevel.rawValue)")

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        logger.logNotice("Audio file loaded, size: \(audioData.count) bytes")

        let base64AudioData = audioData.base64EncodedString()

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        .text(GeminiTextPart(text: config.resolvedPrompt)),
                        .audio(GeminiAudioPart(
                            inlineData: GeminiInlineData(
                                mimeType: audioURL.audioMIMEType,
                                data: base64AudioData
                            )
                        ))
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                thinkingConfig: GeminiThinkingConfig(thinkingLevel: config.thinkingLevel.rawValue)
            )
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            logger.logError("Failed to encode Gemini request: \(error.localizedDescription)")
            throw CloudTranscriptionError.dataEncodingError
        }

        let transcriptionResponse: GeminiResponse
        do {
            transcriptionResponse = try await networkService.sendJSON(request, as: GeminiResponse.self)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        guard let candidate = transcriptionResponse.candidates.first,
              let part = candidate.content.parts.first,
              !part.text.isEmpty else {
            logger.logError("No transcript found in Gemini response")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return part.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct GeminiRequest: Codable {
        let contents: [GeminiContent]
        let generationConfig: GeminiGenerationConfig
    }

    /// Carries the thinking level, which defaults to `.low` - see
    /// ``ThinkingLevel`` for why, and why "minimal" is not on the menu.
    private struct GeminiGenerationConfig: Codable {
        let thinkingConfig: GeminiThinkingConfig
    }

    private struct GeminiThinkingConfig: Codable {
        let thinkingLevel: String
    }

    private struct GeminiContent: Codable {
        let parts: [GeminiPart]
    }

    private enum GeminiPart: Codable {
        case text(GeminiTextPart)
        case audio(GeminiAudioPart)

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let textPart):
                try container.encode(textPart)
            case .audio(let audioPart):
                try container.encode(audioPart)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let textPart = try? container.decode(GeminiTextPart.self) {
                self = .text(textPart)
            } else if let audioPart = try? container.decode(GeminiAudioPart.self) {
                self = .audio(audioPart)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid part"))
            }
        }
    }

    private struct GeminiTextPart: Codable {
        let text: String
    }

    private struct GeminiAudioPart: Codable {
        let inlineData: GeminiInlineData
    }

    private struct GeminiInlineData: Codable {
        let mimeType: String
        let data: String
    }

    // Response types are `internal` (not `private`) so consumer tests can
    // construct a decoded `GeminiResponse` to stub `NetworkService.sendJSON`,
    // which returns an already-decoded value rather than raw `Data`.
    struct GeminiResponse: Codable {
        let candidates: [GeminiCandidate]
    }

    struct GeminiCandidate: Codable {
        let content: GeminiResponseContent
    }

    struct GeminiResponseContent: Codable {
        let parts: [GeminiResponsePart]
    }

    struct GeminiResponsePart: Codable {
        let text: String
    }
}
