//
//  CloudTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.04
//

import Foundation
import TranscriptionCore
import CloudTranscription

class CloudTranscriptionService: TranscriptionService {
    private lazy var groqService = GroqTranscriptionService()
    private lazy var elevenLabsService = ElevenLabsTranscriptionService()
    private lazy var deepgramService = DeepgramTranscriptionService()
    private lazy var geminiService = GeminiTranscriptionService()
    private lazy var mistralService = MistralTranscriptionService()
    private lazy var sonioxService = SonioxTranscriptionService()
    private lazy var gladiaService = GladiaTranscriptionService()
    private lazy var speechmaticsService = SpeechmaticsTranscriptionService()
    private lazy var cohereService = CohereTranscriptionService()
    private lazy var cartesiaService = CartesiaTranscriptionService()
    private lazy var customService = CustomTranscriptionService()

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let result: TranscriptionServiceResult

        switch model.provider {
        case .openAI:
            // Moved to Modules/CloudTranscription. Each call builds a config and
            // an instance because the service is stateless apart from its config.
            guard let cloudModel = model as? CloudModel, let apiKey = cloudModel.apiKey else {
                throw CloudTranscriptionError.missingAPIKey
            }
            let language = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
            let openAI = OpenAITranscriptionService(
                config: .init(apiKey: apiKey, modelName: model.name, language: language)
            )
            result = try await openAI.transcribe(audioURL: audioURL)
        case .groq:
            result = try await groqService.transcribe(audioURL: audioURL, model: model)
        case .elevenLabs:
            result = try await elevenLabsService.transcribe(audioURL: audioURL, model: model)
        case .deepgram:
            result = try await deepgramService.transcribe(audioURL: audioURL, model: model)
        case .gemini:
            result = try await geminiService.transcribe(audioURL: audioURL, model: model)
        case .mistral:
            result = try await mistralService.transcribe(audioURL: audioURL, model: model)
        case .soniox:
            result = try await sonioxService.transcribe(audioURL: audioURL, model: model)
        case .gladia:
            result = try await gladiaService.transcribe(audioURL: audioURL, model: model)
        case .speechmatics:
            result = try await speechmaticsService.transcribe(audioURL: audioURL, model: model)
        case .cohere:
            result = try await cohereService.transcribe(audioURL: audioURL, model: model)
        case .cartesia:
            result = try await cartesiaService.transcribe(audioURL: audioURL, model: model)
        case .customTranscription:
            guard let customModel = model as? CustomTranscriptionModel else {
                throw CloudTranscriptionError.unsupportedProvider
            }
            result = try await customService.transcribe(audioURL: audioURL, model: customModel)
        default:
            throw CloudTranscriptionError.unsupportedProvider
        }

        return result
    }
}
