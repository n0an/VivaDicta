// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
import Foundation
@preconcurrency import FluidAudio
import os
import TranscriptionCore

/// Transcribes audio using a locally-loaded Parakeet (NVIDIA) ASR model via
/// FluidAudio. Caches the model + VAD manager in memory between calls. If the
/// caller passes a non-empty vocabulary list, switches to FluidAudio's
/// sliding-window streaming path with CTC vocabulary boosting.
@MainActor
public final class ParakeetTranscriptionService {

    public struct Options: Sendable {
        public let isVADEnabled: Bool
        /// If non-empty, the service uses sliding-window streaming + CTC
        /// vocabulary boosting. The app target gates this on its own user
        /// settings (spelling corrections + Parakeet vocab boosting) and
        /// passes an empty array when the toggle is off.
        public let vocabulary: [String]

        public init(isVADEnabled: Bool = true, vocabulary: [String] = []) {
            self.isVADEnabled = isVADEnabled
            self.vocabulary = vocabulary
        }
    }

    private var asrManager: AsrManager?
    private var vadManager: VadManager?
    private var cachedVocabularyTerms: [String] = []
    private var cachedVocabularyContext: CustomVocabularyContext?
    private var cachedCtcModels: CtcModels?
    private var cachedCtcTokenizer: CtcTokenizer?
    private let logger = Logger(localTranscriptionCategory: "ParakeetTranscription")
    private let boostedStreamingConfig = SlidingWindowAsrConfig.default

    public init() {}

    public func transcribe(
        audioURL: URL,
        modelName: String,
        displayName: String? = nil,
        version: AsrModelVersion,
        options: Options,
        progressHandler: TranscriptionProgressHandler? = nil
    ) async throws -> TranscriptionServiceResult {
        let label = displayName ?? modelName
        logger.logNotice("🦜 Starting Parakeet transcription with model: \(label)")

        await reportProgress(.init(stage: .preparingAudio), to: progressHandler)

        let audioFile = try AVAudioFile(forReading: audioURL)
        let durationSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        logger.logNotice("📊 Audio duration: \(durationSeconds.formatted(.number.precision(.fractionLength(2)))) seconds")

        if let boostedText = try await transcribeWithVocabularyBoostingIfEnabled(
            audioURL: audioURL,
            version: version,
            durationSeconds: durationSeconds,
            options: options,
            progressHandler: progressHandler
        ) {
            return .plain(boostedText)
        }

        try await loadModel(version: version)

        guard let asrManager else {
            logger.logNotice("🦜 ASR manager not initialized, cannot transcribe")
            throw TranscriptionError.modelLoadFailed
        }

        if durationSeconds < 20.0 || !options.isVADEnabled {
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

        let speechAudio = try await prepareSpeechAudio(from: audioURL)

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

    public func loadModel(version: AsrModelVersion) async throws {
        guard asrManager == nil else {
            return
        }

        do {
            let manager = AsrManager(config: .default)
            let models = try await loadAsrModels(version: version)
            try await manager.loadModels(models)

            self.asrManager = manager
            logger.logNotice("✅ Parakeet ASR model loaded successfully")
        } catch {
            logger.logError("❌ Failed to load Parakeet model: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private

    private func readAndConvertAudio(from url: URL) async throws -> [Float] {
        let converter = AudioConverter()
        return try converter.resampleAudioFile(path: url.path)
    }

    private func prepareSpeechAudio(from audioURL: URL) async throws -> [Float] {
        var speechAudio = try await readAndConvertAudio(from: audioURL)
        speechAudio = try await applyVAD(to: speechAudio)
        return addTrailingSilenceIfNeeded(to: speechAudio)
    }

    private func addTrailingSilenceIfNeeded(to audioSamples: [Float]) -> [Float] {
        let trailingSilenceSamples = 16_000 // 1 second at 16kHz
        let maxSingleChunkSamples = 240_000

        guard audioSamples.count + trailingSilenceSamples <= maxSingleChunkSamples else {
            return audioSamples
        }

        return audioSamples + [Float](repeating: 0, count: trailingSilenceSamples)
    }

    private func loadAsrModels(version: AsrModelVersion) async throws -> AsrModels {
        let isValid = try await AsrModels.isModelValid(version: version)
        if !isValid {
            logger.error("Model validation failed for \(version == .v2 ? "v2" : "v3"). Models are corrupted.")
            throw ParakeetTranscriptionError.modelValidationFailed("Parakeet models are corrupted. Please delete and re-download the model.")
        }

        return try await AsrModels.loadFromCache(configuration: nil, version: version)
    }

    private func applyVAD(to audioSamples: [Float]) async throws -> [Float] {
        let vadConfig = VadConfig(defaultThreshold: 0.7)

        if vadManager == nil {
            do {
                vadManager = try await VadManager(config: vadConfig)
            } catch {
                logger.logWarning("⚠️ VAD init failed, falling back to full audio: \(error.localizedDescription)")
                return audioSamples
            }
        }

        guard let vadManager else {
            logger.logWarning("⚠️ VAD manager not available, using full audio")
            return audioSamples
        }

        do {
            let segments = try await vadManager.segmentSpeechAudio(audioSamples)

            if segments.isEmpty {
                logger.logWarning("⚠️ VAD found no speech segments, using full audio")
                return audioSamples
            }

            let totalSamples = segments.reduce(0) { $0 + $1.count }
            logger.logNotice("📊 VAD extracted \(segments.count) segments, total: \((Double(totalSamples) / 16000.0).formatted(.number.precision(.fractionLength(2))))s")

            return segments.flatMap { $0 }
        } catch {
            logger.logWarning("⚠️ VAD processing failed: \(error.localizedDescription), using full audio")
            return audioSamples
        }
    }

    private func transcribeWithVocabularyBoostingIfEnabled(
        audioURL: URL,
        version: AsrModelVersion,
        durationSeconds: Double,
        options: Options,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> String? {
        guard !options.vocabulary.isEmpty else {
            return nil
        }

        do {
            guard let (vocabulary, ctcModels) = try await loadVocabularyBoostingResources(rawTerms: options.vocabulary) else {
                logger.logInfo("🦜 Vocabulary provided but no usable terms tokenize - falling back to standard Parakeet transcription")
                return nil
            }

            logger.logNotice("🦜 Using Parakeet custom vocabulary boosting with \(vocabulary.terms.count) terms")
            return try await transcribeWithVocabularyBoosting(
                audioURL: audioURL,
                version: version,
                vocabulary: vocabulary,
                ctcModels: ctcModels,
                durationSeconds: durationSeconds,
                isVADEnabled: options.isVADEnabled,
                progressHandler: progressHandler
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.logWarning("⚠️ Parakeet vocabulary boosting failed, falling back to standard transcription: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadVocabularyBoostingResources(rawTerms: [String]) async throws -> (vocabulary: CustomVocabularyContext, ctcModels: CtcModels)? {
        let terms = rawTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !terms.isEmpty else {
            return nil
        }

        let ctcModels = try await loadCachedCtcModels()

        if cachedVocabularyTerms == terms, let cachedVocabularyContext {
            return (cachedVocabularyContext, ctcModels)
        }

        let tokenizer = try await loadCachedCtcTokenizer(for: ctcModels)

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

        let vocabularyContext = CustomVocabularyContext(terms: tokenizedTerms)
        cachedVocabularyTerms = terms
        cachedVocabularyContext = vocabularyContext

        return (vocabularyContext, ctcModels)
    }

    private func loadCachedCtcModels() async throws -> CtcModels {
        if let cachedCtcModels {
            return cachedCtcModels
        }

        let ctcModels = try await CtcModels.downloadAndLoad(variant: .ctc110m)
        cachedCtcModels = ctcModels
        return ctcModels
    }

    private func loadCachedCtcTokenizer(for ctcModels: CtcModels) async throws -> CtcTokenizer {
        if let cachedCtcTokenizer {
            return cachedCtcTokenizer
        }

        let tokenizer = try await CtcTokenizer.load(
            from: CtcModels.defaultCacheDirectory(for: ctcModels.variant)
        )
        cachedCtcTokenizer = tokenizer
        return tokenizer
    }

    private func transcribeWithVocabularyBoosting(
        audioURL: URL,
        version: AsrModelVersion,
        vocabulary: CustomVocabularyContext,
        ctcModels: CtcModels,
        durationSeconds: Double,
        isVADEnabled: Bool,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> String {
        defer {
            vadManager = nil
        }

        let models = try await loadAsrModels(version: version)
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

                let speechAudio = try await prepareSpeechAudio(from: audioURL)

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

public enum ParakeetTranscriptionError: LocalizedError {
    case modelValidationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelValidationFailed(let message):
            return message
        }
    }

    public var failureReason: String? {
        switch self {
        case .modelValidationFailed:
            return "Parakeet model validation failed"
        }
    }
}
