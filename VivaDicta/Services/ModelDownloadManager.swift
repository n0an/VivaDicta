//
//  ModelDownloadManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import SwiftUI
import FluidAudio
import WhisperKit
import os
import FirebaseAnalytics

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
/// models, including progress tracking, cancellation, and cleanup.
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
class ModelDownloadManager: @unchecked Sendable {
    /// Download progress per model (0.0 to 1.0), keyed by model name.
    public var downloadProgress: [String: Double] = [:]

    /// Current download status per model, keyed by model name.
    public var downloadStatuses: [String: DownloadStatus] = [:]

    private var observations: [String: NSKeyValueObservation] = [:]
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
        await MainActor.run {
            downloadStatuses[model.name] = .download
            downloadProgress.removeValue(forKey: model.name + "_main")
            downloadProgress.removeValue(forKey: model.name + "_coreml")
            downloadProgress.removeValue(forKey: model.name)
        }
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
            await MainActor.run {
                downloadStatuses[model.name] = .download
            }
            logger.logNotice("🗑️ Deleted model \(model.name)")
        } else if let whisperKitModel = model as? WhisperKitModel {
            try whisperKitModel.deleteModel()
            await MainActor.run {
                downloadStatuses[model.name] = .download
            }
            logger.logNotice("🗑️ Deleted model \(model.name)")
        } else {
            throw ModelDownloadError.unsupportedModelType
        }
    }


    // MARK: - Parakeet Model Download
    private func downloadParakeetModel(_ model: ParakeetModel) async throws {
        try Task.checkCancellation()

        await MainActor.run {
            downloadStatuses[model.name] = .downloading
            downloadProgress[model.name] = 0.0
        }

        logger.logNotice("📥 Starting download of \(model.displayName)")

        // Start progress simulation - declare outside do block to ensure cleanup
        let progressTask = Task { @MainActor in
            while !Task.isCancelled && self.downloadStatuses[model.name] == .downloading {
                if let currentProgress = self.downloadProgress[model.name], currentProgress < 0.9 {
                    self.downloadProgress[model.name] = min(currentProgress + 0.02, 0.9)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        
        defer {
            progressTask.cancel()
        }

        do {
            async let asrDownload = AsrModels.downloadAndLoad(to: model.modelsDirectory, version: model.version)
            async let vadDownload = DownloadUtils.loadModels(
                .vad,
                modelNames: Array(ModelNames.VAD.requiredModels),
                directory: FileManager.appDirectory(for: .parakeetModels)
            )

            _ = try await (asrDownload, vadDownload)
            
            try Task.checkCancellation()

            await MainActor.run {
                self.downloadProgress[model.name] = 1.0
                self.downloadStatuses[model.name] = .downloaded
                logger.logNotice("✅ Successfully downloaded \(model.displayName)")
            }

            // Log model download to Firebase Analytics
            Analytics.logEvent("model_downloaded", parameters: [
                "model_name": model.displayName,
                "model_type": "parakeet"
            ])

            try? await Task.sleep(for: .seconds(0.5))

            await MainActor.run {
                self.downloadProgress.removeValue(forKey: model.name)
                self.onModelDownloaded?(model)
            }

        } catch is CancellationError {
            logger.logNotice("🛑 Download of \(model.displayName) was cancelled")
            throw CancellationError()
        } catch {
            await MainActor.run {
                self.downloadStatuses[model.name] = .download
                self.downloadProgress.removeValue(forKey: model.name)
            }

            logger.logError("❌ Failed to download \(model.displayName): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - WhisperKit Model Download

    private func downloadWhisperKitModel(_ model: WhisperKitModel) async throws {
        // Check for cancellation before starting
        try Task.checkCancellation()

        await MainActor.run {
            downloadStatuses[model.name] = .downloading
            downloadProgress[model.name] = 0.0
        }

        logger.logNotice("📥 Starting download and preparation of \(model.displayName)")

        do {
            // Initialize WhisperKit without auto-loading
            let config = WhisperKitConfig(
                verbose: false,
                logLevel: .info,
                prewarm: false,
                load: false,
                download: false
            )

            let whisperKit = try await WhisperKit(config)
            
            try Task.checkCancellation()

            // Check if model needs downloading using consolidated path
            let modelFolder = WhisperKitModel.modelPath(for: model.whisperKitModelName)

            if !FileManager.default.fileExists(atPath: modelFolder.path) {
                logger.logNotice("📥 Downloading model: \(model.whisperKitModelName)")

                // Download the model with real progress tracking
                let downloadedFolder = try await WhisperKit.download(
                    variant: model.whisperKitModelName,
                    from: "argmaxinc/whisperkit-coreml",
                    progressCallback: { @Sendable progress in
                        let progressValue = progress.fractionCompleted * 0.7
                        Task { @MainActor in
                            // 70% of progress for download
                            self.downloadProgress[model.name] = progressValue
                        }
                    }
                )
                
                try Task.checkCancellation()

                whisperKit.modelFolder = downloadedFolder
            } else {
                whisperKit.modelFolder = modelFolder
                await MainActor.run {
                    self.downloadProgress[model.name] = 0.7
                }
            }

            // Check for cancellation before prewarm
            try Task.checkCancellation()

            // Prewarm models with animated progress (critical for first-time performance)
            logger.logNotice("🔥 Prewarming model: \(model.whisperKitModelName)")
            await MainActor.run {
                self.downloadProgress[model.name] = 0.75
            }

            // Start progress animation for pre-warming phase
            let progressTask = Task { @MainActor in
                logger.logNotice("📊 Starting pre-warm progress animation from 75% to 90%")
                await self.animateProgressExponentially(
                    for: model.name,
                    from: 0.75,
                    to: 0.9,
                    maxDuration: 240.0 // 4 minutes max
                )
                logger.logNotice("📊 Pre-warm progress animation completed or cancelled")
            }

            let prewarmStart = Date()
            try await whisperKit.prewarmModels()
            let prewarmDuration = Date().timeIntervalSince(prewarmStart)
            logger.logNotice("✅ Model prewarmed in \(prewarmDuration.formatted(.number.precision(.fractionLength(2)))) seconds")

            // Cancel the animation task and set final progress
            progressTask.cancel()

            // Check for cancellation after prewarm
            try Task.checkCancellation()

            await MainActor.run {
                self.downloadProgress[model.name] = 0.9
            }

            // Load models with animated progress
            logger.logNotice("📚 Loading model: \(model.whisperKitModelName)")

            // Start progress animation for loading phase
            let loadProgressTask = Task {
                await self.animateProgressExponentially(
                    for: model.name,
                    from: 0.9,
                    to: 0.99,
                    maxDuration: 60.0 // 1 minute max for loading
                )
            }

            let loadStart = Date()
            try await whisperKit.loadModels()
            let loadDuration = Date().timeIntervalSince(loadStart)
            logger.logNotice("✅ Model loaded in \(loadDuration.formatted(.number.precision(.fractionLength(2)))) seconds")

            // Cancel the animation task and set final progress
            loadProgressTask.cancel()

            // Check for cancellation after load
            try Task.checkCancellation()

            await MainActor.run {
                self.downloadProgress[model.name] = 1.0
                self.downloadStatuses[model.name] = .downloaded
                logger.logNotice("✅ Successfully downloaded and prepared \(model.displayName)")
                logger.logNotice("⏱️ Preparation time: prewarm: \(prewarmDuration.formatted(.number.precision(.fractionLength(2))))s, load: \(loadDuration.formatted(.number.precision(.fractionLength(2))))s")
            }

            // Log model download to Firebase Analytics
            Analytics.logEvent("model_downloaded", parameters: [
                "model_name": model.displayName,
                "model_type": "whisperkit"
            ])

            // Unload models after download to free memory
            // They will be loaded again when needed for transcription
            await whisperKit.unloadModels()

            try? await Task.sleep(for: .seconds(0.5))

            await MainActor.run {
                self.downloadProgress.removeValue(forKey: model.name)
                self.onModelDownloaded?(model)
            }

        } catch is CancellationError {
            logger.logNotice("🛑 Download of \(model.displayName) was cancelled")
            throw CancellationError()
        } catch {
            await MainActor.run {
                self.downloadStatuses[model.name] = .download
                self.downloadProgress.removeValue(forKey: model.name)
            }

            logger.logError("❌ Failed to download \(model.displayName): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Progress Animation

    /// Animates progress exponentially from current value to target value over a maximum duration
    /// Uses exponential decay function for smooth, natural-looking progress animation
    private func animateProgressExponentially(
        for modelName: String,
        from initialProgress: Float,
        to targetProgress: Float,
        maxDuration: TimeInterval
    ) async {
        // Calculate decay constant for exponential approach to target
        // We want to reach ~99% of the target progress range in maxDuration
        let progressRange = targetProgress - initialProgress
        let decayConstant = -log(0.01) / Float(maxDuration) // -log(0.01) ≈ 4.605
        let startTime = Date()

        logger.logInfo("🎯 Starting progress animation: \(initialProgress) -> \(targetProgress) over \(maxDuration)s")
        var updateCount = 0

        while !Task.isCancelled {
            let elapsedTime = Date().timeIntervalSince(startTime)

            // Calculate progress using exponential decay
            // This ensures smooth, continuous progress that asymptotically approaches target
            let decayFactor = exp(-decayConstant * Float(elapsedTime))
            let currentProgress = initialProgress + progressRange * (1 - decayFactor)

            await MainActor.run {
                self.downloadProgress[modelName] = Double(currentProgress)
                updateCount += 1
                if updateCount % 10 == 0 { // Log every 5 seconds (10 * 0.5s)
                    logger.logInfo("📊 Progress update #\(updateCount): \((currentProgress * 100).formatted(.number.precision(.fractionLength(1))))%")
                }
            }

            // Stop when we're close enough to target or time limit exceeded
            if currentProgress >= targetProgress - 0.001 || elapsedTime >= maxDuration {
                logger.logInfo("🏁 Animation ended: final progress \((currentProgress * 100).formatted(.number.precision(.fractionLength(1))))%")
                break
            }

            // Update every 0.5 seconds for smooth animation
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Common Download Utilities

    private func downloadFileWithProgress(from url: URL, progressKey: String) async throws -> Data {
        let destinationURL = FileManager.appDirectory(for: .models).appendingPathComponent(UUID().uuidString)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let tempURL = tempURL else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }

                do {
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    let data = try Data(contentsOf: destinationURL, options: .mappedIfSafe)
                    continuation.resume(returning: data)
                    try? FileManager.default.removeItem(at: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            task.resume()

            let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                let currentProgress = round(progress.fractionCompleted * 100) / 100
                Task { @MainActor in
                    self?.downloadProgress[progressKey] = currentProgress
                }
            }

            // Store observation for potential cleanup
            observations[progressKey] = observation
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
