// Copyright © 2026 Anton Novoselov. All rights reserved.

@preconcurrency import FluidAudio
import Foundation
import TranscriptionCore
import WhisperKit

/// Stateless download helpers that wrap WhisperKit + FluidAudio. The app's
/// `ModelDownloadManager` calls these instead of importing the SDKs directly,
/// keeping `WhisperKit` and `FluidAudio` confined to this module.
///
/// Each download is a one-shot async function. Callers own all UI state
/// (`@Observable` progress dicts, status enums, cancellation tasks). The
/// helpers just translate SDK progress into a uniform `Double` (0.0...1.0).
public enum LocalModelDownloader {
    /// Receives normalized progress between 0.0 and 1.0.
    public typealias ProgressHandler = @Sendable (Double) -> Void

    // MARK: - Parakeet

    /// Downloads (if not cached) and validates the Parakeet ASR model plus the
    /// VAD model for the given version. Progress is unified across both
    /// phases: ASR occupies 0.0...0.85, VAD occupies 0.85...1.0.
    ///
    /// Honors `Task.checkCancellation()` between phases.
    public static func downloadParakeet(
        version: ParakeetModelVersion,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let asrVersion = asrModelVersion(for: version)

        _ = try await AsrModels.downloadAndLoad(
            version: asrVersion,
            progressHandler: { progress in
                onProgress(progress.fractionCompleted * 0.85)
            }
        )

        try Task.checkCancellation()

        _ = try await VadManager(
            progressHandler: { progress in
                onProgress(0.85 + progress.fractionCompleted * 0.15)
            }
        )
    }

    // MARK: - WhisperKit

    /// Phases the WhisperKit setup pipeline emits. Callers use them to drive
    /// their own progress UI (e.g. animate between fixed checkpoints during
    /// the long prewarm + load steps).
    public enum WhisperKitPhase: Sendable {
        /// File download in progress. `fractionCompleted` is 0.0...1.0 across
        /// the network download only.
        case downloading(fractionCompleted: Double)
        /// Files are present on disk (either freshly downloaded or already
        /// cached). Prewarm is about to start.
        case prewarmStart
        /// Prewarm finished; load is about to start.
        case loadStart
        /// Load finished; the model has been unloaded again to free memory.
        case finished
    }

    public typealias WhisperKitPhaseHandler = @Sendable (WhisperKitPhase) -> Void

    /// Downloads the WhisperKit model (if missing), prewarms it, loads it,
    /// then unloads it again. This is the first-run setup flow - subsequent
    /// transcriptions reload from the prewarmed Core ML cache and are fast.
    ///
    /// Honors `Task.checkCancellation()` at each phase boundary.
    public static func downloadAndPrepareWhisperKit(
        modelName: String,
        onPhase: @escaping WhisperKitPhaseHandler
    ) async throws {
        let config = WhisperKitConfig(
            verbose: false,
            logLevel: .info,
            prewarm: false,
            load: false,
            download: false
        )

        let whisperKit = try await WhisperKit(config)
        try Task.checkCancellation()

        let modelFolder = WhisperKitModelPath.directory(forModelName: modelName)

        if FileManager.default.fileExists(atPath: modelFolder.path) {
            whisperKit.modelFolder = modelFolder
            onPhase(.downloading(fractionCompleted: 1.0))
        } else {
            let downloadedFolder = try await WhisperKit.download(
                variant: modelName,
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { @Sendable progress in
                    onPhase(.downloading(fractionCompleted: progress.fractionCompleted))
                }
            )
            whisperKit.modelFolder = downloadedFolder
        }

        try Task.checkCancellation()
        onPhase(.prewarmStart)
        try await whisperKit.prewarmModels()
        try Task.checkCancellation()

        onPhase(.loadStart)
        try await whisperKit.loadModels()
        try Task.checkCancellation()

        await whisperKit.unloadModels()
        onPhase(.finished)
    }
}
