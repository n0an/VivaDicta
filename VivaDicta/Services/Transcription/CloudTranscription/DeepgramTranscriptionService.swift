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
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        try await NetworkRetry.withRetry(logger: logger) {
            try await makeTranscriptionRequest(audioURL: audioURL, model: model)
        }
    }

    private func makeTranscriptionRequest(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        let config = try getAPIConfig(for: model)

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
            return transcript
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
        
        // Build the URL with query parameters
        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        var queryItems: [URLQueryItem] = []
        
        // Add language parameter if not auto-detect
        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
        
        // Choose model based on language
        let modelName = selectedLanguage == "en" ? "nova-3" : "nova-2"
        queryItems.append(URLQueryItem(name: "model", value: modelName))
        
        queryItems.append(contentsOf: [
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "paragraphs", value: "true")
        ])
        
        if selectedLanguage != "auto" && !selectedLanguage.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: selectedLanguage))
        }

        // Add custom vocabulary keywords
        let vocabularyTerms = CustomVocabulary.getTerms(maxTerms: 100)
        if !vocabularyTerms.isEmpty {
            // Nova-3 (including nova-3-multilingual) uses keyterm, Nova-2 uses keywords
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
    
    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
    }
    
    private struct DeepgramResponse: Decodable {
        let results: Results

        struct Results: Decodable {
            let channels: [Channel]

            struct Channel: Decodable {
                let alternatives: [Alternative]

                struct Alternative: Decodable {
                    let transcript: String
                    let confidence: Double?
                }
            }
        }
    }

}
