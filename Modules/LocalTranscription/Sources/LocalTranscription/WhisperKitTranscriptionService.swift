// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
@preconcurrency import SpeakerKit
@preconcurrency import WhisperKit
import os
import TranscriptionCore

/// Transcribes audio using a locally-loaded WhisperKit model. Holds a single
/// model in memory across calls; reloads when asked to transcribe with a
/// different model name. Model downloading is the caller's responsibility -
/// this service expects the model files to already be on disk under
/// `WhisperKitModelPath.directory(forModelName:)`.
/// Marked `@unchecked Sendable` because the service holds mutable state
/// (loaded model, cached durations) that is serialized through the
/// `TranscriptionManager`'s `@MainActor` caller chain. Calls from off-Main
/// would race; the manager is the sole caller and is `@MainActor`.
public final class WhisperKitTranscriptionService: @unchecked Sendable {

    public struct Options: Sendable {
        /// BCP-47 code or `"auto"` to let WhisperKit detect.
        public let language: String
        /// Apply WhisperKit's VAD chunking strategy.
        public let isVADEnabled: Bool
        /// Request word-level timestamps and run SpeakerKit diarization
        /// afterwards to produce a speaker-attributed transcript.
        public let isSpeakerDiarizationEnabled: Bool

        public init(language: String = "auto", isVADEnabled: Bool = true, isSpeakerDiarizationEnabled: Bool = false) {
            self.language = language
            self.isVADEnabled = isVADEnabled
            self.isSpeakerDiarizationEnabled = isSpeakerDiarizationEnabled
        }
    }

    // MARK: - Silence Handling

    /// Whisper answers silence with memorized subtitle credits from its training
    /// data - in Russian the "Субтитры ... DimaTorzok" family, with equivalents
    /// in Turkish, Czech and Arabic. `TranscriptionOutputFilter` strips whatever
    /// reaches the transcript, but these three options stop most of it being
    /// generated at all, which is the better place to fix it.
    ///
    /// A segment is discarded when `noSpeechProb > noSpeechThreshold`, unless
    /// `avgLogProb > logProbThreshold` overrides that (WhisperKit's
    /// `SegmentSeeker.swift`). Memorized credit lines defeat the default pairing
    /// precisely because the model is *confident* about them: high no-speech
    /// probability, but a high average log-probability that buys them a reprieve.
    /// So both ends move - the skip triggers sooner, and the escape hatch is
    /// narrower.

    /// Down from WhisperKit's 0.6, so a quiet segment is called silence sooner.
    private static let noSpeechThreshold: Float = 0.4

    /// Up from WhisperKit's -1.0, narrowing the confidence override that lets a
    /// memorized string survive the no-speech check. Kept well below 0 so
    /// genuinely quiet speech is not thrown away with it.
    private static let logProbThreshold: Float = -0.7

    /// WhisperKit defaults this to `false`; OpenAI's reference implementation
    /// defaults it to `true`. Suppresses blank/whitespace tokens at the start of
    /// a window, which is where a hallucinated credit line begins.
    private static let suppressBlank = true

    private var whisperKit: WhisperKit?
    private var speakerKit: SpeakerKit?
    private var currentModelName: String?
    private var modelState: ModelState = .unloaded
    private let logger = Logger(localTranscriptionCategory: "WhisperKitTranscription")

    /// Time spent in the most-recent `prewarmModels()` call.
    public var lastPrewarmDuration: TimeInterval = 0
    /// Time spent in the most-recent `loadModels()` call.
    public var lastLoadDuration: TimeInterval = 0
    /// Total init time (prewarm + load) for the most-recent model load.
    public var lastTotalInitDuration: TimeInterval = 0

    public init() {}

    /// Transcribes audio at `audioURL` using the WhisperKit model identified by
    /// `modelName`. Loads the model on first use or when switching models.
    public func transcribe(
        audioURL: URL,
        modelName: String,
        displayName: String? = nil,
        options: Options
    ) async throws -> TranscriptionServiceResult {
        if whisperKit == nil || currentModelName != modelName || modelState != .loaded {
            try await loadModel(modelName: modelName)
        }

        guard let whisperKit else {
            throw TranscriptionError.modelLoadFailed
        }

        do {
            let label = displayName ?? modelName
            logger.logNotice("🎯 Starting WhisperKit transcription with model: \(label), VAD: \(options.isVADEnabled)")

            let decodingOptions = DecodingOptions(
                language: (options.language == "auto" ? nil : options.language),
                detectLanguage: (options.language == "auto" ? true : nil),
                wordTimestamps: options.isSpeakerDiarizationEnabled,
                suppressBlank: Self.suppressBlank,
                logProbThreshold: Self.logProbThreshold,
                noSpeechThreshold: Self.noSpeechThreshold,
                chunkingStrategy: options.isVADEnabled ? .vad : nil
            )

            let rawResult = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: decodingOptions)

            // Drop the confident-text-over-silence tail before anything reads
            // the transcript, so diarization and the plain path agree.
            let result = TranscriptionSegmentCleanup.droppingTrailingHallucinations(in: rawResult)
            let droppedSegments = rawResult.reduce(0) { $0 + $1.segments.count }
                - result.reduce(0) { $0 + $1.segments.count }
            if droppedSegments > 0 {
                logger.logNotice("🧹 Dropped \(droppedSegments) trailing hallucinated segment(s)")
            }

            let transcribedText = TranscriptionSegmentCleanup
                .joinedText(result.flatMap(\.segments))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if options.isSpeakerDiarizationEnabled,
               let diarizedResult = await makeSpeakerAttributedResult(from: result, audioURL: audioURL) {
                logger.logNotice("✅ WhisperKit diarization completed successfully")
                return diarizedResult
            }

            logger.logNotice("✅ WhisperKit transcription completed, model kept in memory")
            return .plain(transcribedText)
        } catch {
            logger.logError("❌ WhisperKit transcription failed: \(error.localizedDescription)")
            throw TranscriptionError.transcriptionFailed
        }
    }

    /// Preloads the named model if it's downloaded and not already current.
    /// Failures are logged but not thrown - preload is best-effort.
    public func preloadModelIfNeeded(modelName: String) async {
        guard WhisperKitModelPath.isDownloaded(modelName: modelName) else {
            logger.logNotice("⏭️ Skipping preload: Model \(modelName) not downloaded")
            return
        }

        if currentModelName == modelName && modelState == .loaded {
            logger.logNotice("✅ Model \(modelName) already loaded, no preload needed")
            return
        }

        logger.logNotice("🚀 Preloading WhisperKit model: \(modelName)")

        do {
            try await loadModel(modelName: modelName)
            logger.logNotice("✅ Successfully preloaded WhisperKit model: \(modelName)")
        } catch {
            logger.logError("⚠️ Failed to preload WhisperKit model: \(error.localizedDescription)")
        }
    }

    /// Explicitly unload the currently-loaded model (and speaker model) from memory.
    public func unloadModel() async {
        if whisperKit != nil {
            logger.logNotice("🧹 Manually unloading WhisperKit model")
            await whisperKit?.unloadModels()
            await speakerKit?.unloadModels()
            whisperKit = nil
            speakerKit = nil
            currentModelName = nil
            modelState = .unloaded
        }
    }

    public var currentModelState: ModelState { modelState }

    // MARK: - Private

    private func loadModel(modelName: String) async throws {
        if currentModelName == modelName && modelState == .loaded {
            logger.logNotice("Model \(modelName) already loaded, skipping reload")
            return
        }

        if currentModelName != modelName && whisperKit != nil {
            logger.logNotice("Unloading previous model: \(self.currentModelName ?? "unknown")")
            await whisperKit?.unloadModels()
            whisperKit = nil
            modelState = .unloaded
        }

        do {
            let totalStartTime = Date()
            logger.logNotice("🚀 Starting WhisperKit initialization for model: \(modelName)")

            let config = WhisperKitConfig(
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: false,
                download: false
            )

            whisperKit = try await WhisperKit(config)

            guard let whisperKit else {
                throw TranscriptionError.modelLoadFailed
            }

            let modelFolder = WhisperKitModelPath.directory(forModelName: modelName)

            if !FileManager.default.fileExists(atPath: modelFolder.path) {
                logger.logError("❌ Model not found at path: \(modelFolder.path)")
                logger.logError("Please download the model first")
                throw TranscriptionError.modelNotDownloaded
            }

            whisperKit.modelFolder = modelFolder
            modelState = .downloaded

            logger.logNotice("🔥 Prewarming model: \(modelName)")
            modelState = .prewarming

            let prewarmStart = Date()
            try await whisperKit.prewarmModels()
            let prewarmDuration = Date().timeIntervalSince(prewarmStart)
            lastPrewarmDuration = prewarmDuration

            modelState = .prewarmed
            logger.logNotice("✅ Model prewarmed in \(prewarmDuration.formatted(.number.precision(.fractionLength(2)))) seconds")

            logger.logNotice("📚 Loading model: \(modelName)")
            modelState = .loading

            let loadStart = Date()
            try await whisperKit.loadModels()
            let loadDuration = Date().timeIntervalSince(loadStart)
            lastLoadDuration = loadDuration

            modelState = .loaded
            currentModelName = modelName

            let totalDuration = Date().timeIntervalSince(totalStartTime)
            lastTotalInitDuration = totalDuration
            logger.logNotice("✅ WhisperKit model loaded in \(loadDuration.formatted(.number.precision(.fractionLength(2)))) seconds: \(modelName)")
            logger.logNotice("⏱️ Total initialization: \(totalDuration.formatted(.number.precision(.fractionLength(2)))) seconds")

        } catch {
            modelState = .unloaded
            whisperKit = nil
            currentModelName = nil
            logger.logError("❌ Failed to load WhisperKit model: \(error.localizedDescription)")
            throw error
        }
    }

    private func loadSpeakerKitIfNeeded() async throws -> SpeakerKit {
        if let speakerKit {
            return speakerKit
        }

        let config = PyannoteConfig(load: false, verbose: false)
        let speakerKit = try await SpeakerKit(config)
        self.speakerKit = speakerKit
        return speakerKit
    }

    private func makeSpeakerAttributedResult(
        from transcription: [TranscriptionResult],
        audioURL: URL
    ) async -> TranscriptionServiceResult? {
        do {
            let speakerKit = try await loadSpeakerKitIfNeeded()
            let audioArray = try AudioProcessor.loadAudioAsFloatArray(fromPath: audioURL.path)
            let diarization = try await speakerKit.diarize(audioArray: audioArray)
            let turns = diarization
                .addSpeakerInfo(to: transcription)
                .flatMap { $0 }
                .map { segment in
                    SpeakerTurn(
                        speakerID: segment.speaker.speakerId.map(String.init),
                        text: segment.text
                    )
                }

            guard let diarizedText = SpeakerDiarizationFormatter.format(turns) else {
                return nil
            }

            return .speakerAttributed(diarizedText)
        } catch {
            logger.logWarning("⚠️ WhisperKit diarization failed, falling back to plain transcript: \(error.localizedDescription)")
            return nil
        }
    }
}
