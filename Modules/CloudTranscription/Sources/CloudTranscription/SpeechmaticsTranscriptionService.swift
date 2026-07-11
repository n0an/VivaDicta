// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import TranscriptionCore

/// Pre-configured Speechmatics STT client. Uses an upload + create + poll flow.
/// Maps the VivaDicta `zh` code to Speechmatics' `cmn` internally; all other
/// codes pass through.
public struct SpeechmaticsTranscriptionService: TranscriptionService, Sendable {
    private let logger = Logger(cloudTranscriptionCategory: "SpeechmaticsTranscription")
    private let apiBase = "https://asr.api.speechmatics.com/v2"
    private let maxWaitSeconds: TimeInterval = 300
    private let pollIntervalNanoseconds: UInt64 = 2_000_000_000

    public struct Config: Sendable {
        public let apiKey: String
        /// Internal model name: `speechmatics-batch-v2` (the enhanced model)
        /// or `melia-1` (multilingual with code-switching).
        public let modelName: String
        public let language: String
        public let vocabulary: [String]
        public let isSpeakerDiarizationEnabled: Bool
        /// `""` = no translation requested.
        public let translationTargetLanguage: String

        public init(
            apiKey: String,
            modelName: String = "speechmatics-batch-v2",
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
    private let networkService: any NetworkService

    public init(
        config: Config,
        networkService: any NetworkService = DefaultNetworkService(category: "SpeechmaticsTranscription")
    ) {
        self.config = config
        self.networkService = networkService
    }

    /// Maps our internal model name to the API `model` value. The legacy
    /// internal name predates the `model` property and means the enhanced model.
    private var apiModel: String {
        config.modelName.isEmpty || config.modelName == "speechmatics-batch-v2"
            ? "enhanced"
            : config.modelName
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        guard !config.apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        // Melia-1 does not support translation (Enhanced/Standard only);
        // Speechmatics rejects melia-1 jobs carrying a translation_config.
        // Drop a configured target so the user still gets their transcription.
        let translationTargetAPI: String
        if apiModel == "melia-1" {
            if !config.translationTargetLanguage.isEmpty {
                logger.logInfo("Speechmatics Melia-1 does not support translation; ignoring target \(config.translationTargetLanguage)")
            }
            translationTargetAPI = ""
        } else {
            translationTargetAPI = mapToSpeechmaticsCode(config.translationTargetLanguage)
        }
        let translationEnabled = !translationTargetAPI.isEmpty
        let languageAPI = mapToSpeechmaticsCode(config.language)

        let jobId = try await createJob(language: languageAPI, audioURL: audioURL, translationTarget: translationTargetAPI)
        try await pollJobStatus(id: jobId)
        let result = try await fetchTranscript(
            id: jobId,
            translationEnabled: translationEnabled,
            translationTarget: translationTargetAPI
        )

        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return result
    }

    /// Speechmatics uses `cmn` for Mandarin where the rest of our codebase uses `zh`.
    private func mapToSpeechmaticsCode(_ code: String) -> String {
        code == "zh" ? "cmn" : code
    }

    private func createJob(language: String, audioURL: URL, translationTarget: String) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/jobs") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // `model` replaced the deprecated `operating_point` property and takes
        // the same values plus `melia-1`. Melia-1 detects languages
        // automatically and requires `language: "multi"`; a concrete
        // user-picked language becomes a hint.
        let model = apiModel

        var transcriptionConfig: [String: Any] = ["model": model]
        if model == "melia-1" {
            transcriptionConfig["language"] = "multi"
            if !language.isEmpty, language != "auto" {
                transcriptionConfig["language_hints"] = [language]
            }
        } else {
            transcriptionConfig["language"] = language.isEmpty ? "auto" : language
        }
        if config.isSpeakerDiarizationEnabled {
            transcriptionConfig["diarization"] = "speaker"
        }

        if !config.vocabulary.isEmpty {
            transcriptionConfig["additional_vocab"] = config.vocabulary.map { ["content": $0] }
            logger.logInfo("Adding \(config.vocabulary.count) custom vocabulary terms to Speechmatics request")
        }

        var jobConfig: [String: Any] = [
            "type": "transcription",
            "transcription_config": transcriptionConfig
        ]

        if !translationTarget.isEmpty {
            jobConfig["translation_config"] = [
                "target_languages": [translationTarget]
            ]
            logger.logInfo("Speechmatics translation enabled, target: \(translationTarget)")
        }

        let configData = try JSONSerialization.data(withJSONObject: jobConfig)
        let configString = String(data: configData, encoding: .utf8) ?? "{}"

        let body = try createMultipartBody(fileURL: audioURL, configJSON: configString, boundary: boundary)

        let data: Data
        do {
            (data, _) = try await networkService.upload(request, from: body)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        do {
            let createResponse = try JSONDecoder().decode(CreateJobResponse.self, from: data)
            logger.logInfo("Speechmatics job created with ID: \(createResponse.id)")
            return createResponse.id
        } catch {
            logger.logError("Failed to decode Speechmatics create response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func pollJobStatus(id: String) async throws {
        guard let baseURL = URL(string: "\(apiBase)/jobs/\(id)") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        let start = Date()

        while true {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = NetworkRetry.defaultTimeout
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

            let data: Data
            do {
                (data, _) = try await networkService.send(request)
            } catch let error as NetworkError {
                throw error.asTranscriptionError()
            }

            if let status = try? JSONDecoder().decode(JobStatusResponse.self, from: data) {
                switch status.job.status.lowercased() {
                case "done":
                    logger.logInfo("Speechmatics transcription completed")
                    return
                case "rejected":
                    logger.logError("Speechmatics job rejected")
                    throw CloudTranscriptionError.apiRequestFailed(statusCode: 422, message: "Job rejected")
                default:
                    break
                }
            }

            if Date().timeIntervalSince(start) > maxWaitSeconds {
                logger.logError("Speechmatics transcription timed out after \(maxWaitSeconds) seconds")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: 504, message: "Transcription timed out")
            }

            try await Task.sleep(for: .nanoseconds(pollIntervalNanoseconds))
        }
    }

    private func fetchTranscript(id: String, translationEnabled: Bool, translationTarget: String) async throws -> TranscriptionServiceResult {
        guard let apiURL = URL(string: "\(apiBase)/jobs/\(id)/transcript?format=json-v2") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let data: Data
        do {
            (data, _) = try await networkService.send(request)
        } catch let error as NetworkError {
            throw error.asTranscriptionError()
        }

        guard let decoded = try? JSONDecoder().decode(TranscriptResponse.self, from: data) else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }

        if translationEnabled {
            guard let translations = decoded.translations,
                  let segments = translations[translationTarget],
                  !segments.isEmpty else {
                logger.logError("Speechmatics translation requested but missing or empty in response")
                throw CloudTranscriptionError.noTranscriptionReturned
            }

            if config.isSpeakerDiarizationEnabled,
               let diarized = makeSpeakerAttributedTextFromSegments(segments) {
                return .speakerAttributed(diarized)
            }
            return .plain(segments.compactMap(\.content).joined(separator: " "))
        }

        if config.isSpeakerDiarizationEnabled,
           let diarized = makeSpeakerAttributedTextFromWords(decoded.results) {
            return .speakerAttributed(diarized)
        }
        return .plain(buildPlainTranscript(from: decoded.results))
    }

    /// Speechmatics tokens carry `attaches_to ∈ {previous, next, both, none}`
    /// to control spacing. Honoring it correctly handles opening quotes and
    /// parens (`attaches_to: "next"`) and em-dashes (`attaches_to: "both"`),
    /// not just trailing punctuation.
    private struct AttachmentRule {
        let toPrevious: Bool
        let toNext: Bool
    }

    private func attachmentRule(for item: TranscriptResponse.ResultItem) -> AttachmentRule {
        let isPunctuation = item.type == "punctuation"
        let attachesTo = item.attaches_to ?? (isPunctuation ? "previous" : "")
        return AttachmentRule(
            toPrevious: attachesTo == "previous" || attachesTo == "both",
            toNext: attachesTo == "next" || attachesTo == "both"
        )
    }

    private func buildPlainTranscript(from results: [TranscriptResponse.ResultItem]?) -> String {
        guard let results, !results.isEmpty else { return "" }

        var output = ""
        var skipSpaceBeforeNext = false

        for item in results {
            guard let content = item.alternatives?.first?.content else { continue }
            let rule = attachmentRule(for: item)

            if !output.isEmpty && !skipSpaceBeforeNext && !rule.toPrevious {
                output += " "
            }
            output += content
            skipSpaceBeforeNext = rule.toNext
        }
        return output
    }

    private func makeSpeakerAttributedTextFromWords(_ results: [TranscriptResponse.ResultItem]?) -> String? {
        guard let results, !results.isEmpty else { return nil }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""
        var skipSpaceBeforeNext = false

        for item in results {
            guard let alt = item.alternatives?.first,
                  let content = alt.content else { continue }
            let speaker = alt.speaker
            let rule = attachmentRule(for: item)

            let sameSpeaker = (speaker == currentSpeaker || speaker == nil)

            if currentText.isEmpty && turns.isEmpty {
                currentSpeaker = speaker
                currentText = content
                skipSpaceBeforeNext = rule.toNext
                continue
            }

            if sameSpeaker {
                if !skipSpaceBeforeNext && !rule.toPrevious {
                    currentText += " "
                }
                currentText += content
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = speaker
                currentText = content
            }
            skipSpaceBeforeNext = rule.toNext
        }

        if !currentText.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
        }

        return SpeakerDiarizationFormatter.format(turns)
    }

    private func makeSpeakerAttributedTextFromSegments(_ segments: [TranscriptResponse.TranslationSegment]) -> String? {
        guard !segments.isEmpty else { return nil }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for segment in segments {
            guard let content = segment.content, !content.isEmpty else { continue }
            let speaker = segment.speaker

            if currentText.isEmpty && turns.isEmpty {
                currentSpeaker = speaker
                currentText = content
                continue
            }

            if speaker == currentSpeaker || speaker == nil {
                currentText += " " + content
            } else {
                turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
                currentSpeaker = speaker
                currentText = content
            }
        }

        if !currentText.isEmpty {
            turns.append(SpeakerTurn(speakerID: currentSpeaker, text: currentText))
        }

        return SpeakerDiarizationFormatter.format(turns)
    }

    private func createMultipartBody(fileURL: URL, configJSON: String, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: fileURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"config\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: application/json\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(configJSON.data(using: .utf8) ?? Data())
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data_file\"; filename=\"\(fileURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(fileURL.audioMIMEType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private struct CreateJobResponse: Decodable {
        let id: String
    }

    private struct JobStatusResponse: Decodable {
        let job: JobInfo

        struct JobInfo: Decodable {
            let id: String
            let status: String
        }
    }

    private struct TranscriptResponse: Decodable {
        let results: [ResultItem]?
        let translations: [String: [TranslationSegment]]?

        struct ResultItem: Decodable {
            let type: String?
            let attaches_to: String?
            let alternatives: [Alternative]?
        }

        struct Alternative: Decodable {
            let content: String?
            let speaker: String?
        }

        struct TranslationSegment: Decodable {
            let content: String?
            let speaker: String?
        }
    }
}
