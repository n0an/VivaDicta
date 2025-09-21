//
//  CloudTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.04
//

import Foundation

enum CloudTranscriptionError: LocalizedError {
    case unsupportedProvider
    case missingAPIKey
    case invalidAPIKey
    case audioFileNotFound
    case apiRequestFailed(statusCode: Int, message: String)
    case networkError(any Error)
    case noTranscriptionReturned
    case dataEncodingError

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            return "Unsupported transcription provider"
        case .missingAPIKey:
            return "API key missing"
        case .invalidAPIKey:
            return "Invalid API key"
        case .audioFileNotFound:
            return "Audio file not found"
        case .apiRequestFailed(let statusCode, _):
            return "API request failed (Code \(statusCode))"
        case .networkError(_):
            return "Network error occurred"
        case .noTranscriptionReturned:
            return "Empty response from API"
        case .dataEncodingError:
            return "Failed to encode request"
        }
    }

    var failureReason: String {
        switch self {
        case .unsupportedProvider:
            return "The selected transcription provider is not supported. Please choose a different provider from the settings."
        case .missingAPIKey:
            return "API key for this service is not configured. Go to Settings and add your API key for the selected provider."
        case .invalidAPIKey:
            return "The API key you provided is invalid or has expired. Please check your API key in Settings and ensure it's correct."
        case .audioFileNotFound:
            return "The audio file could not be located on disk. It may have been deleted or moved. Please try recording again."
        case .apiRequestFailed(let statusCode, let message):
            if statusCode == 429 {
                return "Rate limit exceeded. Please wait a moment before trying again. \(message)"
            } else if statusCode >= 500 {
                return "The transcription service is temporarily unavailable. Please try again later. \(message)"
            } else {
                return "The transcription service returned an error: \(message)"
            }
        case .networkError(let error):
            return "Unable to connect to the transcription service. Please check your internet connection and try again. \(error.localizedDescription)"
        case .noTranscriptionReturned:
            return "The transcription service returned an empty response. The audio may be too short or contain no speech."
        case .dataEncodingError:
            return "Failed to prepare the audio data for upload. Please try recording the audio again."
        }
    }
}

class CloudTranscriptionService: TranscriptionService {
    private lazy var openAIService = OpenAITranscriptionService()
    private lazy var groqService = GroqTranscriptionService()
    private lazy var elevenLabsService = ElevenLabsTranscriptionService()
    private lazy var deepgramService = DeepgramTranscriptionService()
    private lazy var geminiService = GeminiTranscriptionService()
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        var text: String
        
        switch model.provider {
        case .openAI:
            text = try await openAIService.transcribe(audioURL: audioURL, model: model)
        case .groq:
            text = try await groqService.transcribe(audioURL: audioURL, model: model)
        case .elevenLabs:
            text = try await elevenLabsService.transcribe(audioURL: audioURL, model: model)
        case .deepgram:
            text = try await deepgramService.transcribe(audioURL: audioURL, model: model)
        case .gemini:
            text = try await geminiService.transcribe(audioURL: audioURL, model: model)
        default:
            throw CloudTranscriptionError.unsupportedProvider
        }
        
        return text
    }
}
