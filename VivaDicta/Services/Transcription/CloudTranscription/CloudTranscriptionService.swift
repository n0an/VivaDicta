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
    private lazy var deepgramService = DeepgramTranscriptionService()
    private lazy var mistralService = MistralTranscriptionService()
    private lazy var sonioxService = SonioxTranscriptionService()
    private lazy var gladiaService = GladiaTranscriptionService()
    private lazy var speechmaticsService = SpeechmaticsTranscriptionService()
    private lazy var customService = CustomTranscriptionService()

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let result: TranscriptionServiceResult

        switch model.provider {
        case .openAI:
            // Moved to Modules/CloudTranscription (PR B1). Builds the config inline.
            let language = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
            let openAI = OpenAITranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: language)
            )
            result = try await openAI.transcribe(audioURL: audioURL)
        case .groq:
            result = try await groqService.transcribe(audioURL: audioURL, model: model)
        case .elevenLabs:
            // Moved to Modules/CloudTranscription (PR B2).
            let language = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
            let elevenLabs = ElevenLabsTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: language)
            )
            result = try await elevenLabs.transcribe(audioURL: audioURL)
        case .deepgram:
            result = try await deepgramService.transcribe(audioURL: audioURL, model: model)
        case .gemini:
            // Moved to Modules/CloudTranscription (PR B2). No language used by Gemini.
            let gemini = GeminiTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name)
            )
            result = try await gemini.transcribe(audioURL: audioURL)
        case .mistral:
            result = try await mistralService.transcribe(audioURL: audioURL, model: model)
        case .soniox:
            result = try await sonioxService.transcribe(audioURL: audioURL, model: model)
        case .gladia:
            result = try await gladiaService.transcribe(audioURL: audioURL, model: model)
        case .speechmatics:
            result = try await speechmaticsService.transcribe(audioURL: audioURL, model: model)
        case .cohere:
            // Moved to Modules/CloudTranscription (PR B2). Cohere doesn't accept
            // "auto"; fall back to "en" when the user picks auto or an
            // unsupported code.
            let language = normalizedLanguage(
                for: UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto",
                supportedCodes: Set(TranscriptionModelProvider.cohereLanguages.keys),
                fallback: "en"
            )
            let cohere = CohereTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: language)
            )
            result = try await cohere.transcribe(audioURL: audioURL)
        case .cartesia:
            // Moved to Modules/CloudTranscription (PR B2). Same `auto -> en`
            // fallback policy as Cohere.
            let language = normalizedLanguage(
                for: UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto",
                supportedCodes: Set(TranscriptionModelProvider.cartesiaLanguages.keys),
                fallback: "en"
            )
            let cartesia = CartesiaTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: language)
            )
            result = try await cartesia.transcribe(audioURL: audioURL)
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

    private func requireAPIKey(_ model: any TranscriptionModel) throws -> String {
        guard let cloudModel = model as? CloudModel, let apiKey = cloudModel.apiKey, !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        return apiKey
    }

    private func normalizedLanguage(for picked: String, supportedCodes: Set<String>, fallback: String) -> String {
        if picked == "auto" || picked.isEmpty || !supportedCodes.contains(picked) {
            return fallback
        }
        return picked
    }
}
