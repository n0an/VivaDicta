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

struct OpenAITranscriptionService: TranscribtionService {
    let apiKey = "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"
    
    public func generateAudioTransciptions(fileURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: fileURL)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        let boundary: String = UUID().uuidString
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let bodyBuilder = MultipartFormDataBodyBuilder(boundary: boundary, entries: [
            .file(paramName: "file", fileName: "recording.m4a", fileData: audioData, contentType: "audio/mpeg"),
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
}


