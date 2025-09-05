//
//  OpenAITranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.05
//

import Foundation

enum OpenAITranscriptionServiceError: Error {
    case data
    case format
    case statusCode(Int)
}

struct OpenAITranscriptionService {
    //    var selectedLanguage: Language
        
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        
        let config = try getAPIConfig(for: model)
        
        let audioData = try Data(contentsOf: audioURL)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        let boundary: String = UUID().uuidString
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let bodyBuilder = MultipartFormDataBodyBuilder(
            boundary: boundary,
            entries: [
                .file(paramName: "file",
                      fileName: "recording.m4a",
                      fileData: audioData,
                      contentType: "audio/mpeg"),
                .string(paramName: "model", value: "gpt-4o-transcribe"),
                .string(paramName: "response_format", value: "text")
            ])
        request.httpBody = bodyBuilder.build()
        
        
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw OpenAITranscriptionServiceError.statusCode((resp as? HTTPURLResponse)?.statusCode ?? -1)
            
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAITranscriptionServiceError.format
        }
        
        return text

    }
    
    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let cloudModel = model as? CloudModel,
              let apiKey = cloudModel.apiKey,
              !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        
        let apiURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        return APIConfig(url: apiURL, apiKey: apiKey, modelName: model.name)
    }
    
    
    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
    }
    
    
    

    
//    public func generateAudioTransciptions(fileURL: URL) async throws -> String {
//        let audioData = try Data(contentsOf: fileURL)
//        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
//        let boundary: String = UUID().uuidString
//        request.timeoutInterval = 30
//        request.httpMethod = "POST"
//        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
//        
//        let bodyBuilder = MultipartFormDataBodyBuilder(
//            boundary: boundary,
//            entries: [
//                .file(paramName: "file",
//                      fileName: "recording.m4a",
//                      fileData: audioData,
//                      contentType: "audio/mpeg"),
//                .string(paramName: "model", value: "gpt-4o-transcribe"),
//                .string(paramName: "response_format", value: "text")
//            ])
//        request.httpBody = bodyBuilder.build()
//        
//        
//        let (data, resp) = try await URLSession.shared.data(for: request)
//        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
//            throw OpenAITranscriptionServiceError.statusCode((resp as? HTTPURLResponse)?.statusCode ?? -1)
//            
//        }
//        
//        guard let text = String(data: data, encoding: .utf8) else {
//            throw OpenAITranscriptionServiceError.format
//        }
//        
//        return text
//    }
}


