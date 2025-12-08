//
//  ElevenLabsTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.05
//

import Foundation
import os

class ElevenLabsTranscriptionService {
    private let apiURL = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    private let logger = Logger(category: .elevenLabsTranscriptionService)
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        
        
        let config = try getAPIConfig(for: model)
        let apiKey = config.apiKey
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        let body = try createRequestBody(audioURL: audioURL, modelName: model.name, boundary: boundary)
        
        
        // Check for cancellation before making network request
        try Task.checkCancellation()
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        
        
        // Check for cancellation after network request
        try Task.checkCancellation()

        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }
        
        logger.notice("ElevenLabs API Response Status: \(httpResponse.statusCode)")
        if let responseBody = String(data: data, encoding: .utf8) {
            logger.notice("ElevenLabs API Response Body: \(responseBody)")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        do {
            let transcriptionResponse = try JSONDecoder().decode(ElevenLabsTranscriptionResponse.self, from: data)
            return transcriptionResponse.text
        } catch {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }
    
    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let cloudModel = model as? CloudModel,
              let apiKey = cloudModel.apiKey,
              !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        
        let apiURL = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
        return APIConfig(url: apiURL, apiKey: apiKey, modelName: model.name)
    }
    
    
    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
    }
    
    private func createRequestBody(audioURL: URL, modelName: String, boundary: String) throws -> Data {
        var body = Data()
        
        body.append(formField: "file", fileName: audioURL.lastPathComponent, fileData: try Data(contentsOf: audioURL), mimeType: "audio/wav", boundary: boundary)
        body.append(formField: "model_id", value: modelName, boundary: boundary)
        body.append(formField: "temperature", value: "0.0", boundary: boundary)
        body.append(formField: "tag_audio_events", value: "false", boundary: boundary)
        
        let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "auto"
        if selectedLanguage != "auto", !selectedLanguage.isEmpty {
            body.append(formField: "language_code", value: selectedLanguage, boundary: boundary)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private struct ElevenLabsTranscriptionResponse: Decodable {
        let text: String
    }
}

private extension Data {
    mutating func append(formField: String, value: String, boundary: String) {
        let crlf = "\r\n"
        append("--\(boundary)\(crlf)".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(formField)\"\(crlf)\(crlf)".data(using: .utf8)!)
        append(value.data(using: .utf8)!)
        append(crlf.data(using: .utf8)!)
    }
    
    mutating func append(formField: String, fileName: String, fileData: Data, mimeType: String, boundary: String) {
        let crlf = "\r\n"
        append("--\(boundary)\(crlf)".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(formField)\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\(crlf)\(crlf)".data(using: .utf8)!)
        append(fileData)
        append(crlf.data(using: .utf8)!)
    }
}
