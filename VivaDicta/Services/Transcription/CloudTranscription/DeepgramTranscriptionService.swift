//
//  DeepgramTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.05
//

import Foundation
import os

class DeepgramTranscriptionService {
    private let logger = Logger(category: .deepgramService)
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL, model: model)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let config = try getAPIConfig(for: model)
        let diarizationEnabled = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled

        var request = URLRequest(url: config.url)
        request.httpMethod = "POST"
        request.setValue("Token \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(audioURL.audioMIMEType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = NetworkRetry.defaultTimeout

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let (data, response) = try await URLSession.shared.upload(for: request, from: audioData)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.logError("Deepgram API request failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let transcript = transcriptionResponse.results.channels.first?.alternatives.first?.transcript,
                  !transcript.isEmpty else {
                logger.logError("No transcript found in Deepgram response")
                throw CloudTranscriptionError.noTranscriptionReturned
            }

            if diarizationEnabled,
               let diarizedText = makeSpeakerAttributedText(from: transcriptionResponse) {
                return .speakerAttributed(diarizedText)
            }

            return .plain(transcript)
        } catch {
            logger.logError("Failed to decode Deepgram API response: \(error.localizedDescription)")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }
    
    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let cloudModel = model as? CloudModel,
              let apiKey = cloudModel.apiKey,
              !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        
        // Build the URL with query parameters while preserving the selected model.
        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        var queryItems: [URLQueryItem] = []

        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"

        // The app exposes a friendly multilingual alias, but Deepgram expects
        // multilingual Nova-3 as model=nova-3 with language=multi.
        let modelName: String
        let requestLanguage: String?
        if cloudModel.name == "nova-3-multilingual" {
            modelName = "nova-3"
            requestLanguage = "multi"
        } else {
            modelName = cloudModel.name
            if selectedLanguage != "auto" && !selectedLanguage.isEmpty {
                requestLanguage = selectedLanguage
            } else {
                requestLanguage = nil
            }
        }

        queryItems.append(URLQueryItem(name: "model", value: modelName))

        queryItems.append(contentsOf: [
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "paragraphs", value: "true")
        ])

        if AppGroupCoordinator.shared.isSpeakerDiarizationEnabled {
            queryItems.append(URLQueryItem(name: "diarize", value: "true"))
            queryItems.append(URLQueryItem(name: "utterances", value: "true"))
        }

        if let requestLanguage {
            queryItems.append(URLQueryItem(name: "language", value: requestLanguage))
        }

        // Nova-3 models use keyterm prompting, while earlier Nova models use keywords.
        let vocabularyTerms = CustomVocabulary.getTerms(maxTerms: 100)
        if !vocabularyTerms.isEmpty {
            let paramName = modelName.hasPrefix("nova-3") ? "keyterm" : "keywords"
            for term in vocabularyTerms {
                queryItems.append(URLQueryItem(name: paramName, value: term))
            }
            logger.logInfo("Adding \(vocabularyTerms.count) custom vocabulary terms to Deepgram request")
        }

        components.queryItems = queryItems
        
        guard let apiURL = components.url else {
            throw CloudTranscriptionError.dataEncodingError
        }
        
        return APIConfig(url: apiURL, apiKey: apiKey, modelName: model.name)
    }

    private func makeSpeakerAttributedText(from response: DeepgramResponse) -> String? {
        let turns = response.results.utterances?.map {
            SpeakerTurn(
                speakerID: $0.speaker.map(String.init),
                text: $0.transcript
            )
        } ?? []

        return SpeakerDiarizationFormatter.format(turns)
    }
    
    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
    }
    
    private struct DeepgramResponse: Decodable {
        let results: Results

        struct Results: Decodable {
            let channels: [Channel]
            let utterances: [Utterance]?

            struct Channel: Decodable {
                let alternatives: [Alternative]

                struct Alternative: Decodable {
                    let transcript: String
                    let confidence: Double?
                }
            }

            struct Utterance: Decodable {
                let speaker: Int?
                let transcript: String
            }
        }
    }

}
