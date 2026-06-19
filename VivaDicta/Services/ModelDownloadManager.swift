//
//  ModelDownloadManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import LocalTranscription
import Analytics
import SwiftUI
import TranscriptionCore
import os

/// Status of a model download operation.
enum DownloadStatus: String {
    case download
    case downloading
    case downloaded

    var actionButtonImage: String {
        switch self {
        case .download:
            "arrow.down.circle.fill"
        case .downloading:
            "xmark.circle"
        case .downloaded:
            "trash.circle"
        }
    }

    var actionButtonColor: Color {
        switch self {
        case .download:
                .blue
        case .downloading:
                .primary
        case .downloaded:
                .red
        }
    }
}

/// Manager for downloading, tracking, and deleting on-device transcription models.
///
/// `ModelDownloadManager` handles the download lifecycle for WhisperKit and Parakeet
/// models, including progress tracking, cancellation, and cleanup. SDK-level work
/// is delegated to `LocalTranscription.LocalModelDownloader` so this file does not
/// import `WhisperKit` or `FluidAudio` directly.
///
/// ## Overview
///
/// The manager provides:
/// - Download progress tracking per model
/// - Download status management (download, downloading, downloaded)
/// - Cancellation with partial file cleanup
/// - Model deletion
/// - Callbacks when downloads complete
///
/// ## Usage
///
/// ```swift
/// let manager = ModelDownloadManager()
///
/// // Download a model
/// try await manager.downloadModel(whisperKitModel)
///
/// // Track progress
/// let progress = manager.currentProgress(for: model)
///
/// // Cancel if needed
/// manager.cancelDownload(for: model)
/// ```
@Observable
class ModelDownloadManager {
    /// Download progress per model (0.0 to 1.0), keyed by model name.
    public var downloadProgress: [String: Double] = [:]

    /// Current download status per model, keyed by model name.
    public var downloadStatuses: [String: DownloadStatus] = [:]

    private var downloadTasks: [String: Task<Void, any Error>] = [:]
    private let logger = Logger(category: .modelDownloadManager)

    /// Callback invoked when a model download completes successfully.
    public var onModelDownloaded: ((any TranscriptionModel) -> Void)?

    // MARK: - Public Interface

    /// Downloads a transcription model.
    ///
    /// - Parameter model: The model to download (WhisperKit or Parakeet).
    /// - Throws: ``ModelDownloadError`` if the download fails.
    public func downloadModel(_ model: any TranscriptionModel) async throws {
        let task = Task {
            if let parakeetModel = model as? ParakeetModel {
                try await downloadParakeetModel(parakeetModel)
            } else if let whisperKitModel = model as? WhisperKitModel {
                try await downloadWhisperKitModel(whisperKitModel)
            } else {
                throw ModelDownloadError.unsupportedModelType
            }
        }

        // Store the task for potential cancellation
        downloadTasks[model.name] = task

        // Wait for the task to complete and clean up
        defer {
            downloadTasks.removeValue(forKey: model.name)
        }

        try await task.value
    }

    /// Handles a model download error by resetting status and logging.
    ///
    /// - Parameters:
    ///   - model: The model that failed to download.
    ///   - error: The error that occurred.
    public func handleModelDownloadError(_ model: any TranscriptionModel, _ error: any Error) async {
        downloadStatuses[model.name] = .download
        downloadProgress.removeValue(forKey: model.name + "_main")
        downloadProgress.removeValue(forKey: model.name + "_coreml")
        downloadProgress.removeValue(forKey: model.name)
        logger.logError("Error downloading model \(model.name): \(error.localizedDescription)")
    }

    /// Returns the current download progress for a model (0.0 to 1.0).
    ///
    /// - Parameter model: The model to check.
    /// - Returns: Progress value between 0.0 and 1.0.
    public func currentProgress(for model: any TranscriptionModel) -> Double {
        if model is ParakeetModel || model is WhisperKitModel {
            return downloadProgress[model.name] ?? 0.0
        }
        return 0.0
    }

    /// Returns the current download status for a model.
    ///
    /// - Parameter model: The model to check.
    /// - Returns: The download status.
    public func downloadStatus(for model: any TranscriptionModel) -> DownloadStatus {
        if let parakeetModel = model as? ParakeetModel {
            return downloadStatuses[model.name] ?? (parakeetModel.isDownloaded ? .downloaded : .download)
        } else if let whisperKitModel = model as? WhisperKitModel {
            return downloadStatuses[model.name] ?? (whisperKitModel.isDownloaded ? .downloaded : .download)
        }
        return .download
    }

    /// Cancels an in-progress download and cleans up partial files.
    ///
    /// - Parameter model: The model whose download should be cancelled.
    public func cancelDownload(for model: any TranscriptionModel) {
        // Cancel the download task if it exists
        if let task = downloadTasks[model.name] {
            task.cancel()
            downloadTasks.removeValue(forKey: model.name)
        }

        // Reset status and progress
        Task { @MainActor in
            downloadStatuses[model.name] = .download
            downloadProgress.removeValue(forKey: model.name)
            downloadProgress.removeValue(forKey: model.name + "_main")
            downloadProgress.removeValue(forKey: model.name + "_coreml")
        }

        // Clean up any partially downloaded files
        Task {
            do {
                if let parakeetModel = model as? ParakeetModel {
                    try parakeetModel.deleteModel()
                    logger.logNotice("🧹 Cleaned up partial download for \(model.name)")
                } else if let whisperKitModel = model as? WhisperKitModel {
                    try whisperKitModel.deleteModel()
                    logger.logNotice("🧹 Cleaned up partial download for \(model.name)")
                }
            } catch {
                // Ignore cleanup errors - folder may not exist yet
                logger.logInfo("No partial download to clean up for \(model.name)")
            }
        }

        logger.logNotice("❌ Cancelled download of \(model.name)")
    }

    /// Deletes a downloaded model from disk.
    ///
    /// - Parameter model: The model to delete.
    /// - Throws: ``ModelDownloadError/unsupportedModelType`` if the model type isn't supported.
    public func deleteModel(_ model: any TranscriptionModel) async throws {
        if let parakeetModel = model as? ParakeetModel {
            try parakeetModel.deleteModel()
            downloadStatuses[model.name] = .download
            logger.logNotice("🗑️ Deleted model \(model.name)")
        } else if let whisperKitModel = model as? WhisperKitModel {
            try whisperKitModel.deleteModel()
            downloadStatuses[model.name] = .download
            logger.logNotice("🗑️ Deleted model \(model.name)")
        } else {
            throw ModelDownloadError.unsupportedModelType
        }
    }

    // MARK: - Parakeet Model Download

    private func downloadParakeetModel(_ model: ParakeetModel) async throws {
        try Task.checkCancellation()

        downloadStatuses[model.name] = .downloading
        downloadProgress[model.name] = 0.0

        logger.logNotice("📥 Starting download of \(model.displayName)")

        let modelName = model.name

        do {
            try await LocalModelDownloader.downloadParakeet(
                version: model.version,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        guard let self else { return }
                        guard self.downloadStatuses[modelName] == .downloading else { return }
                        self.downloadProgress[modelName] = progress
                    }
                }
            )

            try Task.checkCancellation()

            downloadProgress[model.name] = 1.0
            downloadStatuses[model.name] = .downloaded
            logger.logNotice("✅ Successfully downloaded \(model.displayName)")

            DefaultAnalyticsService.live.track(.modelDownloaded(name: model.displayName, type: "parakeet"))

            try? await Task.sleep(for: .seconds(0.5))

            downloadProgress.removeValue(forKey: model.name)
            onModelDownloaded?(model)

        } catch is CancellationError {
            logger.logNotice("🛑 Download of \(model.displayName) was cancelled")
            throw CancellationError()
        } catch {
            downloadStatuses[model.name] = .download
            downloadProgress.removeValue(forKey: model.name)

            logger.logError("❌ Failed to download \(model.displayName): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - WhisperKit Model Download

    private func downloadWhisperKitModel(_ model: WhisperKitModel) async throws {
        try Task.checkCancellation()

        downloadStatuses[model.name] = .downloading
        downloadProgress[model.name] = 0.0

        logger.logNotice("📥 Starting download and preparation of \(model.displayName)")

        let modelName = model.name
        let displayName = model.displayName
        let whisperKitModelName = model.whisperKitModelName

        let phaseState = WhisperKitPhaseState()

        do {
            try await LocalModelDownloader.downloadAndPrepareWhisperKit(
                modelName: whisperKitModelName,
                onPhase: { [weak self] phase in
                    Task { @MainActor in
                        guard let self else { return }
                        switch phase {
                        case .downloading(let fractionCompleted):
                            // First 70% of overall progress represents the download.
                            self.downloadProgress[modelName] = fractionCompleted * 0.7

                        case .prewarmStart:
                            self.logger.logNotice("🔥 Prewarming model: \(whisperKitModelName)")
                            self.downloadProgress[modelName] = 0.75
                            phaseState.prewarmStart = Date()
                            phaseState.prewarmProgressTask = Task { @MainActor [weak self] in
                                self?.logger.logNotice("📊 Starting pre-warm progress animation from 75% to 90%")
                                await self?.animateProgressExponentially(
                                    for: modelName,
                                    from: 0.75,
                                    to: 0.9,
                                    maxDuration: 240.0
                                )
                                self?.logger.logNotice("📊 Pre-warm progress animation completed or cancelled")
                            }

                        case .loadStart:
                            if let prewarmStart = phaseState.prewarmStart {
                                phaseState.prewarmDuration = Date().timeIntervalSince(prewarmStart)
                                self.logger.logNotice("✅ Model prewarmed in \(phaseState.prewarmDuration.formatted(.number.precision(.fractionLength(2)))) seconds")
                            }
                            phaseState.prewarmProgressTask?.cancel()
                            self.downloadProgress[modelName] = 0.9
                            self.logger.logNotice("📚 Loading model: \(whisperKitModelName)")
                            phaseState.loadStart = Date()
                            phaseState.loadProgressTask = Task { @MainActor [weak self] in
                                await self?.animateProgressExponentially(
                                    for: modelName,
                                    from: 0.9,
                                    to: 0.99,
                                    maxDuration: 60.0
                                )
                            }

                        case .finished:
                            if let loadStart = phaseState.loadStart {
                                phaseState.loadDuration = Date().timeIntervalSince(loadStart)
                                self.logger.logNotice("✅ Model loaded in \(phaseState.loadDuration.formatted(.number.precision(.fractionLength(2)))) seconds")
                            }
                            phaseState.loadProgressTask?.cancel()
                        }
                    }
                }
            )

            try Task.checkCancellation()

            downloadProgress[model.name] = 1.0
            downloadStatuses[model.name] = .downloaded
            logger.logNotice("✅ Successfully downloaded and prepared \(displayName)")
            logger.logNotice("⏱️ Preparation time: prewarm: \(phaseState.prewarmDuration.formatted(.number.precision(.fractionLength(2))))s, load: \(phaseState.loadDuration.formatted(.number.precision(.fractionLength(2))))s")

            DefaultAnalyticsService.live.track(.modelDownloaded(name: displayName, type: "whisperkit"))

            try? await Task.sleep(for: .seconds(0.5))

            downloadProgress.removeValue(forKey: model.name)
            onModelDownloaded?(model)

        } catch is CancellationError {
            phaseState.prewarmProgressTask?.cancel()
            phaseState.loadProgressTask?.cancel()
            logger.logNotice("🛑 Download of \(displayName) was cancelled")
            throw CancellationError()
        } catch {
            phaseState.prewarmProgressTask?.cancel()
            phaseState.loadProgressTask?.cancel()
            downloadStatuses[model.name] = .download
            downloadProgress.removeValue(forKey: model.name)

            logger.logError("❌ Failed to download \(displayName): \(error.localizedDescription)")
            throw error
        }
    }

    /// Mutable state shared between the WhisperKit phase callback and the
    /// surrounding download orchestration. All reads/writes happen inside
    /// `Task { @MainActor in ... }` blocks, so concurrent access is
    /// serialized by the MainActor; that lets us mark it `@unchecked
    /// Sendable` and capture it by reference from the `@Sendable` phase
    /// closure.
    private final class WhisperKitPhaseState: @unchecked Sendable {
        var prewarmStart: Date?
        var prewarmDuration: TimeInterval = 0
        var loadStart: Date?
        var loadDuration: TimeInterval = 0
        var prewarmProgressTask: Task<Void, Never>?
        var loadProgressTask: Task<Void, Never>?
    }

    // MARK: - Progress Animation

    /// Animates progress exponentially from current value to target value over a maximum duration.
    /// Uses exponential decay function for smooth, natural-looking progress animation.
    private func animateProgressExponentially(
        for modelName: String,
        from initialProgress: Float,
        to targetProgress: Float,
        maxDuration: TimeInterval
    ) async {
        let progressRange = targetProgress - initialProgress
        let decayConstant = -log(0.01) / Float(maxDuration)
        let startTime = Date()

        logger.logInfo("🎯 Starting progress animation: \(initialProgress) -> \(targetProgress) over \(maxDuration)s")
        var updateCount = 0

        while !Task.isCancelled {
            let elapsedTime = Date().timeIntervalSince(startTime)

            let decayFactor = exp(-decayConstant * Float(elapsedTime))
            let currentProgress = initialProgress + progressRange * (1 - decayFactor)

            downloadProgress[modelName] = Double(currentProgress)
            updateCount += 1
            if updateCount % 10 == 0 {
                logger.logInfo("📊 Progress update #\(updateCount): \((currentProgress * 100).formatted(.number.precision(.fractionLength(1))))%")
            }

            if currentProgress >= targetProgress - 0.001 || elapsedTime >= maxDuration {
                logger.logInfo("🏁 Animation ended: final progress \((currentProgress * 100).formatted(.number.precision(.fractionLength(1))))%")
                break
            }

            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

/// Errors that can occur during model download operations.
enum ModelDownloadError: LocalizedError {
    case invalidURL
    case unzipFailed
    case downloadFailed(String)
    case unsupportedModelType

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .unzipFailed:
            return "Failed to unzip model"
        case .downloadFailed(_):
            return "Download failed"
        case .unsupportedModelType:
            return "Unsupported model type"
        }
    }

    var failureReason: String {
        switch self {
        case .invalidURL:
            return "The download URL for this model is invalid or missing. Please try a different model or contact support."
        case .unzipFailed:
            return "Failed to extract the downloaded Core ML model. The download may be corrupted. Please try downloading again."
        case .downloadFailed(let message):
            return "Failed to download the model: \(message). Please check your internet connection and try again."
        case .unsupportedModelType:
            return "This model type is not supported for download."
        }
    }
}
