//
//  SpeechmaticsTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.29
//

import Foundation
import os

struct SpeechmaticsTranscriptionService {
    private let logger = Logger(category: .speechmaticsTranscriptionService)
    private let apiBase = "https://asr.api.speechmatics.com/v2"
    private let maxWaitSeconds: TimeInterval = 300
    private let pollIntervalNanoseconds: UInt64 = 2_000_000_000

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let config = try getAPIConfig(for: model)
        let diarizationEnabled = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled
        let translationTargetUI = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kTranslationTargetLanguageKey) ?? ""
        let translationEnabled = !translationTargetUI.isEmpty
        let translationTargetAPI = mapToSpeechmaticsCode(translationTargetUI)

        let selectedLanguageUI = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
        let selectedLanguageAPI = mapToSpeechmaticsCode(selectedLanguageUI)

        let jobId = try await createJob(
            audioURL: audioURL,
            apiKey: config.apiKey,
            language: selectedLanguageAPI,
            diarizationEnabled: diarizationEnabled,
            translationTarget: translationTargetAPI
        )
        try await pollJobStatus(id: jobId, apiKey: config.apiKey)
        let result = try await fetchTranscript(
            id: jobId,
            apiKey: config.apiKey,
            diarizationEnabled: diarizationEnabled,
            translationEnabled: translationEnabled,
            translationTarget: translationTargetAPI
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

    /// Speechmatics uses `cmn` for Mandarin where the rest of our codebase uses `zh`.
    /// Other codes pass through unchanged.
    private func mapToSpeechmaticsCode(_ code: String) -> String {
        code == "zh" ? "cmn" : code
    }

    private func createJob(
        audioURL: URL,
        apiKey: String,
        language: String,
        diarizationEnabled: Bool,
        translationTarget: String
    ) async throws -> String {
        guard let apiURL = URL(string: "\(apiBase)/jobs") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var transcriptionConfig: [String: Any] = [
            "language": language.isEmpty ? "auto" : language,
            "operating_point": "enhanced"
        ]
        if diarizationEnabled {
            transcriptionConfig["diarization"] = "speaker"
        }

        let vocabularyTerms = CustomVocabulary.getTerms()
        if !vocabularyTerms.isEmpty {
            transcriptionConfig["additional_vocab"] = vocabularyTerms.map { ["content": $0] }
            logger.logInfo("Adding \(vocabularyTerms.count) custom vocabulary terms to Speechmatics request")
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

        let body = try createMultipartBody(
            fileURL: audioURL,
            configJSON: configString,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Speechmatics create job failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
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

    private func pollJobStatus(id: String, apiKey: String) async throws {
        guard let baseURL = URL(string: "\(apiBase)/jobs/\(id)") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        let start = Date()

        while true {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = NetworkRetry.defaultTimeout
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
                logger.logError("Speechmatics status poll failed with status \(httpResponse.statusCode): \(errorMessage)")
                throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
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

            try Task.checkCancellation()
            try await Task.sleep(for: .nanoseconds(pollIntervalNanoseconds))
        }
    }

    private func fetchTranscript(
        id: String,
        apiKey: String,
        diarizationEnabled: Bool,
        translationEnabled: Bool,
        translationTarget: String
    ) async throws -> TranscriptionServiceResult {
        guard let apiURL = URL(string: "\(apiBase)/jobs/\(id)/transcript?format=json-v2") else {
            throw CloudTranscriptionError.dataEncodingError
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.timeoutInterval = NetworkRetry.defaultTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Speechmatics fetch transcript failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard let decoded = try? JSONDecoder().decode(TranscriptResponse.self, from: data) else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }

        if translationEnabled {
            // Translation lives at top-level `translations.<target>` as an array of segments.
            // If it's missing, we surface an error rather than falling back to the original
            // language - the user explicitly requested translation.
            guard let translations = decoded.translations,
                  let segments = translations[translationTarget],
                  !segments.isEmpty else {
                logger.logError("Speechmatics translation requested but missing or empty in response")
                throw CloudTranscriptionError.noTranscriptionReturned
            }

            if diarizationEnabled,
               let diarized = makeSpeakerAttributedTextFromSegments(segments) {
                return .speakerAttributed(diarized)
            }
            return .plain(segments.compactMap(\.content).joined(separator: " "))
        }

        if diarizationEnabled,
           let diarized = makeSpeakerAttributedTextFromWords(decoded.results) {
            return .speakerAttributed(diarized)
        }
        return .plain(buildPlainTranscript(from: decoded.results))
    }

    /// Speechmatics returns one item per word/punctuation in `results[]`.
    /// Concatenate words; punctuation tokens carry `attaches_to: "previous"`
    /// so we glue them onto the prior word without an extra space.
    private func buildPlainTranscript(from results: [TranscriptResponse.ResultItem]?) -> String {
        guard let results, !results.isEmpty else { return "" }

        var output = ""
        for item in results {
            guard let content = item.alternatives?.first?.content else { continue }
            if item.type == "punctuation" || item.attaches_to == "previous" {
                output += content
            } else {
                if !output.isEmpty {
                    output += " "
                }
                output += content
            }
        }
        return output
    }

    private func makeSpeakerAttributedTextFromWords(_ results: [TranscriptResponse.ResultItem]?) -> String? {
        guard let results, !results.isEmpty else { return nil }

        var turns: [SpeakerTurn] = []
        var currentSpeaker: String?
        var currentText = ""

        for item in results {
            guard let alt = item.alternatives?.first,
                  let content = alt.content else { continue }
            let speaker = alt.speaker

            let isPunctuation = item.type == "punctuation" || item.attaches_to == "previous"

            if currentText.isEmpty && turns.isEmpty {
                currentSpeaker = speaker
                currentText = content
                continue
            }

            if speaker == currentSpeaker || speaker == nil {
                if isPunctuation {
                    currentText += content
                } else {
                    currentText += " " + content
                }
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

    /// Translation segments are sentence-level (each carries `content` and optional `speaker`).
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

        // config part
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"config\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: application/json\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(configJSON.data(using: .utf8) ?? Data())
        body.append(crlf.data(using: .utf8)!)

        // data_file part
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data_file\"; filename=\"\(fileURL.lastPathComponent)\"\(crlf)".data(using: .utf8)!)
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
