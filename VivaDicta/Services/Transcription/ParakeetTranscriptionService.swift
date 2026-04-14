//
//  ParakeetTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.27
//

import AVFoundation
import Foundation
@preconcurrency import FluidAudio
import os

class ParakeetTranscriptionService: TranscriptionService {
    private var asrManager: AsrManager?
    private var vadManager: VadManager?
    private let logger = Logger(category: .parakeetTranscriptionService)
    private let boostedStreamingConfig = SlidingWindowAsrConfig.default

    init() {}

    func loadModel(model: ParakeetModel) async throws {
        guard asrManager == nil else {
            return
        }

        do {
            let manager = AsrManager(config: .default)
            let models = try await loadAsrModels(for: model)
            try await manager.loadModels(models)

            self.asrManager = manager
            logger.logNotice("✅ Parakeet ASR model loaded successfully")
        } catch {
            logger.logError("❌ Failed to load Parakeet model: \(error.localizedDescription)")
            throw error
        }
    }
 
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        try await transcribe(audioURL: audioURL, model: model, progressHandler: nil)
    }

    func transcribe(
        audioURL: URL,
        model: any TranscriptionModel,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> TranscriptionServiceResult {
        guard let parakeetModel = model as? ParakeetModel else {
            throw TranscriptionError.unsupportedModel
        }

        logger.logNotice("🦜 Starting Parakeet transcription with model: \(parakeetModel.displayName)")

        await reportProgress(.init(stage: .preparingAudio), to: progressHandler)

        let audioFile = try AVAudioFile(forReading: audioURL)
        let durationSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        logger.logNotice("📊 Audio duration: \(durationSeconds.formatted(.number.precision(.fractionLength(2)))) seconds")

        // Apply VAD for recordings longer than 20 seconds
        // VAD setting should be shared with keyboard extension
        let isVADEnabled = UserDefaultsStorage.shared.object(forKey: AppGroupCoordinator.kIsVADEnabled) as? Bool ?? true

        if let boostedText = try await transcribeWithVocabularyBoostingIfEnabled(
            audioURL: audioURL,
            model: parakeetModel,
            durationSeconds: durationSeconds,
            isVADEnabled: isVADEnabled,
            progressHandler: progressHandler
        ) {
            return .plain(boostedText)
        }

        try await loadModel(model: parakeetModel)

        guard let asrManager = asrManager else {
            logger.logNotice("🦜 ASR manager not initialized, cannot transcribe")
            throw TranscriptionError.modelLoadFailed
        }

        if durationSeconds < 20.0 || !isVADEnabled {
            logger.logNotice("🎙️ Using direct file transcription for Parakeet")
            await reportProgress(.init(stage: .transcribing), to: progressHandler)

            let shouldObserveProgress = durationSeconds > 15.0
            let result = try await transcribeWithProgressObservation(
                using: asrManager,
                shouldObserveProgress: shouldObserveProgress,
                progressHandler: progressHandler
            ) {
                try await asrManager.transcribe(audioURL, source: .system)
            }

            await cleanupAfterTranscription(using: asrManager)
            logger.logNotice("✅ Parakeet transcription completed successfully")
            return .plain(result.text)
        }

        logger.logNotice("🎙️ Applying VAD for long audio (> 20s)")
        await reportProgress(.init(stage: .detectingSpeech), to: progressHandler)

        // VAD segmentation still requires 16kHz mono Float32 samples.
        var speechAudio = try await readAndConvertAudio(from: audioURL)
        speechAudio = try await applyVAD(to: speechAudio)

        // Add trailing silence to improve final word punctuation detection
        let trailingSilenceSamples = 16_000 // 1 second at 16kHz
        let maxSingleChunkSamples = 240_000
        if speechAudio.count + trailingSilenceSamples <= maxSingleChunkSamples {
            speechAudio += [Float](repeating: 0, count: trailingSilenceSamples)
        }

        await reportProgress(.init(stage: .transcribing), to: progressHandler)

        let shouldObserveProgress = speechAudio.count > 240_000
        let result = try await transcribeWithProgressObservation(
            using: asrManager,
            shouldObserveProgress: shouldObserveProgress,
            progressHandler: progressHandler
        ) {
            try await asrManager.transcribe(speechAudio, source: .system)
        }

        await cleanupAfterTranscription(using: asrManager)
        logger.logNotice("✅ Parakeet transcription completed successfully")
        return .plain(result.text)
    }

    private func readAndConvertAudio(from url: URL) async throws -> [Float] {
        // Use AudioConverter from FluidAudio to properly convert audio to 16kHz mono
        let converter = AudioConverter()
        return try converter.resampleAudioFile(path: url.path)
    }

    private func loadAsrModels(for model: ParakeetModel) async throws -> AsrModels {
        let isValid = try await AsrModels.isModelValid(version: model.version)
        if !isValid {
            logger.error("Model validation failed for \(model.version == .v2 ? "v2" : "v3"). Models are corrupted.")
            throw ParakeetTranscriptionError.modelValidationFailed("Parakeet models are corrupted. Please delete and re-download the model.")
        }

        return try await AsrModels.loadFromCache(configuration: nil, version: model.version)
    }

    private func applyVAD(to audioSamples: [Float]) async throws -> [Float] {
        let vadConfig = VadConfig(defaultThreshold: 0.7)

        // Initialize VAD manager if needed (uses FluidAudio's default cache)
        if vadManager == nil {
            do {
                vadManager = try await VadManager(config: vadConfig)
            } catch {
                logger.logWarning("⚠️ VAD init failed, falling back to full audio: \(error.localizedDescription)")
                return audioSamples
            }
        }

        guard let vadManager = vadManager else {
            logger.logWarning("⚠️ VAD manager not available, using full audio")
            return audioSamples
        }

        do {
            // Segment speech using VAD
            let segments = try await vadManager.segmentSpeechAudio(audioSamples)

            if segments.isEmpty {
                logger.logWarning("⚠️ VAD found no speech segments, using full audio")
                return audioSamples
            }

            // Concatenate all speech segments
            let totalSamples = segments.reduce(0) { $0 + $1.count }
            logger.logNotice("📊 VAD extracted \(segments.count) segments, total: \((Double(totalSamples) / 16000.0).formatted(.number.precision(.fractionLength(2))))s")

            return segments.flatMap { $0 }
        } catch {
            logger.logWarning("⚠️ VAD processing failed: \(error.localizedDescription), using full audio")
            return audioSamples
        }
    }

    private var isVocabularyBoostingEnabled: Bool {
        UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isParakeetVocabularyBoostingEnabled)
    }

    private func transcribeWithVocabularyBoostingIfEnabled(
        audioURL: URL,
        model: ParakeetModel,
        durationSeconds: Double,
        isVADEnabled: Bool,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> String? {
        guard isVocabularyBoostingEnabled else {
            return nil
        }

        do {
            guard let (vocabulary, ctcModels) = try await loadVocabularyBoostingResources() else {
                logger.logInfo("🦜 Vocabulary boosting enabled but no usable vocabulary terms found - falling back to standard Parakeet transcription")
                return nil
            }

            logger.logNotice("🦜 Using Parakeet custom vocabulary boosting with \(vocabulary.terms.count) terms")
            return try await transcribeWithVocabularyBoosting(
                audioURL: audioURL,
                model: model,
                vocabulary: vocabulary,
                ctcModels: ctcModels,
                durationSeconds: durationSeconds,
                isVADEnabled: isVADEnabled,
                progressHandler: progressHandler
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.logWarning("⚠️ Parakeet vocabulary boosting failed, falling back to standard transcription: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadVocabularyBoostingResources() async throws -> (vocabulary: CustomVocabularyContext, ctcModels: CtcModels)? {
        let terms = CustomVocabulary.getTerms()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !terms.isEmpty else {
            return nil
        }

        let ctcModels = try await CtcModels.downloadAndLoad(variant: .ctc110m)
        let tokenizer = try await CtcTokenizer.load(
            from: CtcModels.defaultCacheDirectory(for: ctcModels.variant)
        )

        let tokenizedTerms = terms.compactMap { term -> CustomVocabularyTerm? in
            let tokenIds = tokenizer.encode(term)
            guard !tokenIds.isEmpty else { return nil }

            return CustomVocabularyTerm(
                text: term,
                weight: 10.0,
                aliases: nil,
                tokenIds: nil,
                ctcTokenIds: tokenIds
            )
        }

        guard !tokenizedTerms.isEmpty else {
            return nil
        }

        return (CustomVocabularyContext(terms: tokenizedTerms), ctcModels)
    }

    private func transcribeWithVocabularyBoosting(
        audioURL: URL,
        model: ParakeetModel,
        vocabulary: CustomVocabularyContext,
        ctcModels: CtcModels,
        durationSeconds: Double,
        isVADEnabled: Bool,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> String {
        defer {
            vadManager = nil
        }

        let models = try await loadAsrModels(for: model)
        let slidingManager = SlidingWindowAsrManager(config: boostedStreamingConfig)

        do {
            try await slidingManager.configureVocabularyBoosting(
                vocabulary: vocabulary,
                ctcModels: ctcModels
            )
            try await slidingManager.start(models: models, source: .system)

            if durationSeconds < 20.0 || !isVADEnabled {
                logger.logNotice("🎙️ Using vocabulary-boosted file transcription for Parakeet")
                await reportProgress(.init(stage: .transcribing), to: progressHandler)
                try await streamAudioFile(
                    at: audioURL,
                    to: slidingManager,
                    progressHandler: progressHandler
                )
            } else {
                logger.logNotice("🎙️ Applying VAD before vocabulary-boosted Parakeet transcription")
                await reportProgress(.init(stage: .detectingSpeech), to: progressHandler)

                var speechAudio = try await readAndConvertAudio(from: audioURL)
                speechAudio = try await applyVAD(to: speechAudio)

                let trailingSilenceSamples = 16_000
                let maxSingleChunkSamples = 240_000
                if speechAudio.count + trailingSilenceSamples <= maxSingleChunkSamples {
                    speechAudio += [Float](repeating: 0, count: trailingSilenceSamples)
                }

                await reportProgress(.init(stage: .transcribing), to: progressHandler)
                try await streamAudioSamples(
                    speechAudio,
                    to: slidingManager,
                    progressHandler: progressHandler
                )
            }

            let text = try await slidingManager.finish()
            await slidingManager.cleanup()
            logger.logNotice("✅ Parakeet transcription with custom vocabulary completed successfully")
            return text
        } catch {
            await slidingManager.cleanup()
            throw error
        }
    }

    private func streamAudioFile(
        at audioURL: URL,
        to slidingManager: SlidingWindowAsrManager,
        progressHandler: TranscriptionProgressHandler?
    ) async throws {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let converter = AudioConverter()
        let totalFrames = max(audioFile.length, 1)
        let framesPerBuffer: AVAudioFrameCount = 32_768
        var framesRead: AVAudioFramePosition = 0

        while true {
            try Task.checkCancellation()

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: framesPerBuffer
            ) else {
                throw TranscriptionError.audioConversionFailed
            }

            try audioFile.read(into: buffer)
            if buffer.frameLength == 0 {
                break
            }

            let samples = try converter.resampleBuffer(buffer)
            if !samples.isEmpty {
                try await slidingManager.streamFloatSamples(samples)
            }
            framesRead += AVAudioFramePosition(buffer.frameLength)

            let fractionCompleted = min(Double(framesRead) / Double(totalFrames), 0.99)
            await reportProgress(
                .init(stage: .transcribing, fractionCompleted: fractionCompleted),
                to: progressHandler
            )
        }
    }

    private func streamAudioSamples(
        _ audioSamples: [Float],
        to slidingManager: SlidingWindowAsrManager,
        progressHandler: TranscriptionProgressHandler?
    ) async throws {
        let chunkSize = 16_000
        let totalSamples = max(audioSamples.count, 1)
        var startIndex = 0

        while startIndex < audioSamples.count {
            try Task.checkCancellation()

            let endIndex = min(startIndex + chunkSize, audioSamples.count)
            let chunk = Array(audioSamples[startIndex..<endIndex])
            try await slidingManager.streamFloatSamples(chunk)

            let fractionCompleted = min(Double(endIndex) / Double(totalSamples), 0.99)
            await reportProgress(
                .init(stage: .transcribing, fractionCompleted: fractionCompleted),
                to: progressHandler
            )

            startIndex = endIndex
        }
    }

    private func reportProgress(
        _ progress: TranscriptionProgressInfo,
        to progressHandler: TranscriptionProgressHandler?
    ) async {
        guard let progressHandler else { return }
        await progressHandler(progress)
    }

    private func cleanupAfterTranscription(using asrManager: AsrManager) async {
        await asrManager.cleanup()
        self.asrManager = nil
        self.vadManager = nil
        logger.logNotice("🦜 Parakeet ASR models cleaned up from memory")
    }

    private func transcribeWithProgressObservation(
        using asrManager: AsrManager,
        shouldObserveProgress: Bool,
        progressHandler: TranscriptionProgressHandler?,
        operation: () async throws -> ASRResult
    ) async throws -> ASRResult {
        let observationTask = await makeProgressObservationTask(
            using: asrManager,
            shouldObserveProgress: shouldObserveProgress,
            progressHandler: progressHandler
        )
        defer {
            observationTask?.cancel()
        }

        return try await operation()
    }

    private func makeProgressObservationTask(
        using asrManager: AsrManager,
        shouldObserveProgress: Bool,
        progressHandler: TranscriptionProgressHandler?
    ) async -> Task<Void, Never>? {
        guard shouldObserveProgress, let progressHandler else {
            return nil
        }

        let progressStream = await asrManager.transcriptionProgressStream
        return Task {
            do {
                for try await progress in progressStream {
                    await progressHandler(
                        .init(stage: .transcribing, fractionCompleted: progress)
                    )
                }
            } catch {
                return
            }
        }
    }
}

enum ParakeetTranscriptionError: LocalizedError {
    case modelValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelValidationFailed(let message):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .modelValidationFailed:
            return "Parakeet model validation failed"
        }
    }
}
