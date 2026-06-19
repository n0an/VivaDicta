
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import Foundation
import AppGroup
import CloudTranscription
import LocalTranscription
import SwiftUI
import TranscriptionCore
import TranscriptionKit
import os
import AICore

/// Central manager coordinating all transcription services in VivaDicta.
///
/// Routes audio-to-text requests through `TranscriptionKit.TranscriptionEngine`,
/// which dispatches to the right cloud or on-device backend based on the
/// `TranscriptionProvider` value the manager constructs from the current
/// `VivaMode` + user settings. After transcription, applies the app's
/// post-processing pipeline (output filter, text formatter, replacements,
/// trailing-period strip).
///
/// ## Thread Safety
///
/// `@MainActor`-isolated for explicit serialization. The engine's cached
/// local services (WhisperKit, Parakeet) hold mutable state that's safe
/// only because the manager serializes access.
@MainActor
@Observable
class TranscriptionManager: Transcriber {
    private let logger = Logger(category: .transcriptionManager)

    private let engine: any TranscriptionEngine
    private let customTranscriptionSource: any CustomTranscriptionModelSource

    init(
        engine: any TranscriptionEngine = DefaultTranscriptionEngine(),
        customTranscriptionSource: any CustomTranscriptionModelSource = CustomTranscriptionModelManager.shared
    ) {
        self.engine = engine
        self.customTranscriptionSource = customTranscriptionSource
    }

    /// The currently active transcription mode determining which model to use.
    private(set) var currentMode: VivaMode = .defaultMode

    /// Callback invoked when cloud models are updated (e.g., API key changes).
    public var onCloudModelsUpdate: (() -> Void)?

    /// All available transcription models across all providers.
    var allAvailableModels: [any TranscriptionModel] =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels

    /// Indicates whether at least one transcription model is available for use.
    var hasAvailableTranscriptionModels: Bool {
        let hasParakeetModels = !TranscriptionModelProvider.allParakeetModels.filter { $0.isDownloaded }.isEmpty
        let hasWhisperKitModels = !TranscriptionModelProvider.allWhisperKitModels.filter { $0.isDownloaded }.isEmpty
        let hasConfiguredCloudModels = TranscriptionModelProvider.allCloudModels.contains { model in
            model.apiKey != nil
        }
        let hasCustomModel = customTranscriptionSource.isConfigured
        return hasParakeetModels || hasWhisperKitModels || hasConfiguredCloudModels || hasCustomModel
    }

    var selectedLanguage: String {
        get {
            UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "en"
        }
        set {
            UserDefaultsStorage.shared.set(newValue, forKey: AppGroupCoordinator.kSelectedLanguageKey)
        }
    }

    /// Target language for inline translation during transcription (Soniox).
    /// Empty string means no translation.
    var translationTargetLanguage: String {
        get {
            UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kTranslationTargetLanguageKey) ?? ""
        }
        set {
            UserDefaultsStorage.shared.set(newValue, forKey: AppGroupCoordinator.kTranslationTargetLanguageKey)
        }
    }

    /// Sets the current transcription mode and applies its language setting.
    public func setCurrentMode(_ mode: VivaMode) {
        currentMode = mode
        applyModeLanguage(mode)
    }

    private func updateLanguage(_ language: String) {
        selectedLanguage = language
    }

    private func applyModeLanguage(_ mode: VivaMode) {
        let language = mode.transcriptionLanguage ?? "auto"
        updateLanguage(language)
        translationTargetLanguage = mode.translationTargetLanguage ?? ""
    }

    /// Refreshes the list of available cloud models and notifies observers.
    public func updateCloudModels() {
        allAvailableModels =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels
        onCloudModelsUpdate?()
    }

    /// Returns the transcription model for the current mode if it's available and usable.
    public func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let provider = currentMode.transcriptionProvider
        let modelName = currentMode.transcriptionModel

        if provider == .customTranscription && modelName == "custom" {
            return customTranscriptionSource.configuredModel
        }

        let allModels: [any TranscriptionModel] =
        TranscriptionModelProvider.allParakeetModels +
        TranscriptionModelProvider.allWhisperKitModels +
        TranscriptionModelProvider.allCloudModels

        guard let model = allModels.first(where: { $0.provider == provider && $0.name == modelName }) else {
            return nil
        }

        if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.isDownloaded ? parakeetModel : nil
        } else if let whisperKitModel = model as? WhisperKitModel {
            return whisperKitModel.isDownloaded ? whisperKitModel : nil
        } else if let cloudModel = model as? CloudModel {
            return cloudModel.apiKey != nil ? cloudModel : nil
        }

        return model
    }

    /// Transcribes audio using the current mode's model via `TranscriptionEngine`,
    /// then applies the app's post-processing pipeline (filter, text formatter,
    /// replacements, trailing-period strip).
    public func transcribe(
        audioURL: URL,
        progressHandler: TranscriptionProgressHandler? = nil
    ) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw TranscriptionError.transcriptionFailed
        }

        let startTime = Date()
        let provider = try makeProvider(for: model)
        let transcriptionResult = try await engine.transcribe(
            audioURL: audioURL,
            using: provider,
            progress: progressHandler
        )

        // When inline translation is active (e.g. Soniox Spanish → Russian) the
        // output text is in the TARGET language, so the filler set must match the
        // target, not the source transcription language - otherwise target-language
        // fillers (e.g. Russian "э-э") survive.
        var result = TranscriptionOutputFilter.filter(
            transcriptionResult.text,
            language: Self.outputLanguage(
                transcriptionLanguage: currentMode.transcriptionLanguage,
                translationTargetLanguage: currentMode.translationTargetLanguage
            )
        )

        if currentMode.isAutoTextFormattingEnabled && transcriptionResult.isSpeakerAttributed == false {
            result = TextFormatter.format(result)
        }

        if UserDefaults.standard.object(forKey: UserDefaultsStorage.Keys.isReplacementsEnabled) as? Bool ?? true {
            result = ReplacementsService.applyReplacements(to: result)
        }

        if UserDefaults.standard.object(forKey: UserDefaultsStorage.Keys.isStripTrailingPeriodEnabled) as? Bool ?? false {
            result = TranscriptionOutputFilter.stripTrailingPeriods(result)
        }

        AnalyticsService.track(.transcriptionCompleted(
            engine: model.provider.rawValue,
            isOnDevice: TranscriptionModelProvider.localProviders.contains(model.provider),
            durationSeconds: Date().timeIntervalSince(startTime),
            outputLength: result.count
        ))

        return result
    }

    /// Resolves the language of the transcription *output* for post-processing.
    ///
    /// When inline translation is active the output is in the translation target
    /// language; otherwise it's the source transcription language. Returns the
    /// target language whenever it's set (non-nil and non-empty), falling back to
    /// the source language.
    static func outputLanguage(
        transcriptionLanguage: String?,
        translationTargetLanguage: String?
    ) -> String? {
        if let target = translationTargetLanguage, !target.isEmpty {
            return target
        }
        return transcriptionLanguage
    }

    /// Preloads the WhisperKit model if the current mode uses it. Best-effort
    /// background load that makes the first real transcription faster.
    public func preloadWhisperKitModelIfNeeded() async {
        guard currentMode.transcriptionProvider == .whisperKit else {
            logger.logInfo("📱 Preload skipped: Current mode doesn't use WhisperKit (uses \(self.currentMode.transcriptionProvider.rawValue))")
            return
        }

        guard let model = getCurrentTranscriptionModel(),
              let whisperKitModel = model as? WhisperKitModel else {
            logger.logInfo("📱 Preload skipped: No valid WhisperKit model in current mode")
            return
        }

        logger.logInfo("📱 Starting WhisperKit model preload for: \(whisperKitModel.whisperKitModelName)")
        await engine.preloadWhisperKitModel(named: whisperKitModel.whisperKitModelName)
    }

    // MARK: - Provider Construction

    /// Builds the `TranscriptionProvider` value for the given model. The
    /// manager owns the UserDefaults + AppGroupCoordinator reads so the
    /// engine and the underlying services stay agnostic of user-facing
    /// toggles.
    private func makeProvider(
        for model: any TranscriptionModel
    ) throws -> TranscriptionProvider {
        let selectedLanguage = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey) ?? "auto"
        let isVADEnabled = UserDefaultsStorage.shared.object(forKey: AppGroupCoordinator.kIsVADEnabled) as? Bool ?? true
        let diarizationEnabled = AppGroupCoordinator.shared.isSpeakerDiarizationEnabled
        let translationTarget = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kTranslationTargetLanguageKey) ?? ""

        switch model.provider {
        case .parakeet:
            guard let parakeetModel = model as? ParakeetModel else {
                throw TranscriptionError.unsupportedModel
            }
            return .parakeet(
                modelName: parakeetModel.name,
                displayName: parakeetModel.displayName,
                version: parakeetModel.version,
                options: .init(isVADEnabled: isVADEnabled, vocabulary: parakeetVocabularyIfEnabled())
            )

        case .whisperKit:
            guard let whisperKitModel = model as? WhisperKitModel else {
                throw TranscriptionError.unsupportedModel
            }
            return .whisperKit(
                modelName: whisperKitModel.whisperKitModelName,
                displayName: whisperKitModel.displayName,
                options: .init(
                    language: selectedLanguage,
                    isVADEnabled: isVADEnabled,
                    isSpeakerDiarizationEnabled: diarizationEnabled
                )
            )

        case .openAI:
            return .openAI(.init(apiKey: try requireAPIKey(model), modelName: model.name, language: selectedLanguage))

        case .groq:
            return .groq(.init(
                apiKey: try requireAPIKey(model),
                modelName: model.name,
                language: selectedLanguage,
                vocabulary: CustomVocabulary.getTerms(maxTerms: 25)
            ))

        case .elevenLabs:
            return .elevenLabs(.init(
                apiKey: try requireAPIKey(model),
                modelName: model.name,
                language: selectedLanguage,
                isSpeakerDiarizationEnabled: diarizationEnabled
            ))

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
            return .deepgram(.init(
                apiKey: try requireAPIKey(model),
                modelName: modelName,
                language: language,
                vocabulary: CustomVocabulary.getTerms(maxTerms: 100),
                isSpeakerDiarizationEnabled: diarizationEnabled
            ))

        case .gemini:
            return .gemini(.init(apiKey: try requireAPIKey(model), modelName: model.name))

        case .mistral:
            return .mistral(.init(
                apiKey: try requireAPIKey(model),
                modelName: model.name,
                language: selectedLanguage,
                isSpeakerDiarizationEnabled: diarizationEnabled
            ))

        case .soniox:
            return .soniox(.init(
                apiKey: try requireAPIKey(model),
                modelName: model.name,
                language: selectedLanguage,
                vocabulary: CustomVocabulary.getTerms(),
                isSpeakerDiarizationEnabled: diarizationEnabled,
                translationTargetLanguage: translationTarget
            ))

        case .gladia:
            return .gladia(.init(
                apiKey: try requireAPIKey(model),
                language: selectedLanguage,
                vocabulary: CustomVocabulary.getTerms(),
                isSpeakerDiarizationEnabled: diarizationEnabled,
                translationTargetLanguage: translationTarget
            ))

        case .speechmatics:
            return .speechmatics(.init(
                apiKey: try requireAPIKey(model),
                language: selectedLanguage,
                vocabulary: CustomVocabulary.getTerms(),
                isSpeakerDiarizationEnabled: diarizationEnabled,
                translationTargetLanguage: translationTarget
            ))

        case .assemblyAI:
            // AssemblyAI keyterms_prompt allows up to 200 terms on Universal-2
            // (the lower of the two limits, and the language fallback model).
            return .assemblyAI(.init(
                apiKey: try requireAPIKey(model),
                modelName: model.name,
                language: selectedLanguage,
                vocabulary: CustomVocabulary.getTerms(maxTerms: 200),
                isSpeakerDiarizationEnabled: diarizationEnabled
            ))

        case .cohere:
            let language = normalizedLanguage(
                for: selectedLanguage,
                supportedCodes: Set(TranscriptionModelProvider.cohereLanguages.keys),
                fallback: "en"
            )
            return .cohere(.init(apiKey: try requireAPIKey(model), modelName: model.name, language: language))

        case .cartesia:
            let language = normalizedLanguage(
                for: selectedLanguage,
                supportedCodes: Set(TranscriptionModelProvider.cartesiaLanguages.keys),
                fallback: "en"
            )
            return .cartesia(.init(apiKey: try requireAPIKey(model), modelName: model.name, language: language))

        case .xai:
            // xAI STT rejects `format=true` without a language, so fall back to
            // "en" whenever the globally selected language is "auto".
            let language = normalizedLanguage(
                for: selectedLanguage,
                supportedCodes: Set(TranscriptionModelProvider.xaiLanguages.keys),
                fallback: "en"
            )
            return .xai(.init(
                apiKey: try requireAPIKey(model),
                language: language,
                isSpeakerDiarizationEnabled: diarizationEnabled
            ))

        case .customTranscription:
            guard let customModel = model as? CustomTranscriptionModel else {
                throw CloudTranscriptionError.unsupportedProvider
            }
            return .custom(.init(
                apiEndpoint: customModel.apiEndpoint,
                apiKey: customModel.apiKey,
                modelName: customModel.modelName,
                language: selectedLanguage
            ))
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

    /// Returns the custom vocabulary terms when both spelling corrections and
    /// Parakeet vocabulary boosting are enabled by the user. Empty otherwise.
    private func parakeetVocabularyIfEnabled() -> [String] {
        let spellingEnabled = UserDefaultsStorage.appPrivate.object(
            forKey: UserDefaultsStorage.Keys.isSpellingCorrectionsEnabled
        ) as? Bool ?? true

        let boostingEnabled = UserDefaultsStorage.appPrivate.bool(
            forKey: UserDefaultsStorage.Keys.isParakeetVocabularyBoostingEnabled
        )

        guard spellingEnabled && boostingEnabled else { return [] }
        return CustomVocabulary.getTerms()
    }
}
