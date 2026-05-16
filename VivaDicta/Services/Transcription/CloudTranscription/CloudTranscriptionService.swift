//
//  CloudTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.04
//

import Foundation
import AppGroup
import TranscriptionCore
import CloudTranscription

class CloudTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
        let diarizationEnabled = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled
        let translationTarget = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kTranslationTargetLanguageKey) ?? ""

        switch model.provider {
        case .openAI:
            let openAI = OpenAITranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: selectedLanguage)
            )
            return try await openAI.transcribe(audioURL: audioURL)

        case .groq:
            let groq = GroqTranscriptionService(
                config: .init(
                    apiKey: try requireAPIKey(model),
                    modelName: model.name,
                    language: selectedLanguage,
                    vocabulary: CustomVocabulary.getTerms(maxTerms: 25)
                )
            )
            return try await groq.transcribe(audioURL: audioURL)

        case .elevenLabs:
            let elevenLabs = ElevenLabsTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: selectedLanguage)
            )
            return try await elevenLabs.transcribe(audioURL: audioURL)

        case .deepgram:
            // The app exposes `nova-3-multilingual` as a friendly alias; Deepgram
            // expects model=nova-3 with language=multi.
            let modelName: String
            let language: String
            if model.name == "nova-3-multilingual" {
                modelName = "nova-3"
                language = "multi"
            } else {
                modelName = model.name
                language = selectedLanguage
            }
            let deepgram = DeepgramTranscriptionService(
                config: .init(
                    apiKey: try requireAPIKey(model),
                    modelName: modelName,
                    language: language,
                    vocabulary: CustomVocabulary.getTerms(maxTerms: 100),
                    isSpeakerDiarizationEnabled: diarizationEnabled
                )
            )
            return try await deepgram.transcribe(audioURL: audioURL)

        case .gemini:
            let gemini = GeminiTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name)
            )
            return try await gemini.transcribe(audioURL: audioURL)

        case .mistral:
            let mistral = MistralTranscriptionService(
                config: .init(
                    apiKey: try requireAPIKey(model),
                    modelName: model.name,
                    language: selectedLanguage,
                    isSpeakerDiarizationEnabled: diarizationEnabled
                )
            )
            return try await mistral.transcribe(audioURL: audioURL)

        case .soniox:
            let soniox = SonioxTranscriptionService(
                config: .init(
                    apiKey: try requireAPIKey(model),
                    modelName: model.name,
                    language: selectedLanguage,
                    vocabulary: CustomVocabulary.getTerms(),
                    isSpeakerDiarizationEnabled: diarizationEnabled,
                    translationTargetLanguage: translationTarget
                )
            )
            return try await soniox.transcribe(audioURL: audioURL)

        case .gladia:
            let gladia = GladiaTranscriptionService(
                config: .init(
                    apiKey: try requireAPIKey(model),
                    language: selectedLanguage,
                    vocabulary: CustomVocabulary.getTerms(),
                    isSpeakerDiarizationEnabled: diarizationEnabled,
                    translationTargetLanguage: translationTarget
                )
            )
            return try await gladia.transcribe(audioURL: audioURL)

        case .speechmatics:
            let speechmatics = SpeechmaticsTranscriptionService(
                config: .init(
                    apiKey: try requireAPIKey(model),
                    language: selectedLanguage,
                    vocabulary: CustomVocabulary.getTerms(),
                    isSpeakerDiarizationEnabled: diarizationEnabled,
                    translationTargetLanguage: translationTarget
                )
            )
            return try await speechmatics.transcribe(audioURL: audioURL)

        case .cohere:
            let language = normalizedLanguage(
                for: selectedLanguage,
                supportedCodes: Set(TranscriptionModelProvider.cohereLanguages.keys),
                fallback: "en"
            )
            let cohere = CohereTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: language)
            )
            return try await cohere.transcribe(audioURL: audioURL)

        case .cartesia:
            let language = normalizedLanguage(
                for: selectedLanguage,
                supportedCodes: Set(TranscriptionModelProvider.cartesiaLanguages.keys),
                fallback: "en"
            )
            let cartesia = CartesiaTranscriptionService(
                config: .init(apiKey: try requireAPIKey(model), modelName: model.name, language: language)
            )
            return try await cartesia.transcribe(audioURL: audioURL)

        case .customTranscription:
            guard let customModel = model as? CustomTranscriptionModel else {
                throw CloudTranscriptionError.unsupportedProvider
            }
            let custom = CustomTranscriptionService(
                config: .init(
                    apiEndpoint: customModel.apiEndpoint,
                    apiKey: customModel.apiKey,
                    modelName: customModel.modelName,
                    language: selectedLanguage
                )
            )
            return try await custom.transcribe(audioURL: audioURL)

        default:
            throw CloudTranscriptionError.unsupportedProvider
        }
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
