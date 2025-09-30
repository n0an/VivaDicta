//
//  ModelDownloadManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import Foundation
import Zip
import FluidAudio
import WhisperKit
import os

enum DownloadStatus: String {
    case download
    case downloading
    case downloaded
}

@Observable
class ModelDownloadManager: @unchecked Sendable {
    public var downloadProgress: [String: Double] = [:]
    public var downloadStatuses: [String: DownloadStatus] = [:]
    private var observations: [String: NSKeyValueObservation] = [:]
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "ModelDownloadManager")
    public var onModelDownloaded: ((any TranscriptionModel) -> Void)?

    // MARK: - Public Interface

    public func downloadModel(_ model: any TranscriptionModel) async throws {
        if let whisperModel = model as? WhisperLocalModel {
            try await downloadWhisperModel(whisperModel)
        } else if let parakeetModel = model as? ParakeetModel {
            try await downloadParakeetModel(parakeetModel)
        } else if let whisperKitModel = model as? WhisperKitModel {
            try await downloadWhisperKitModel(whisperKitModel)
        } else {
            throw ModelDownloadError.unsupportedModelType
        }
    }

    public func handleModelDownloadError(_ model: any TranscriptionModel, _ error: any Error) async {
        await MainActor.run {
            downloadStatuses[model.name] = .download
            downloadProgress.removeValue(forKey: model.name + "_main")
            downloadProgress.removeValue(forKey: model.name + "_coreml")
            downloadProgress.removeValue(forKey: model.name)
        }
        logger.error("Error downloading model \(model.name): \(error.localizedDescription)")
    }

    public func currentProgress(for model: any TranscriptionModel) -> Double {
        if let whisperModel = model as? WhisperLocalModel {
            return currentProgressForWhisper(whisperModel)
        } else if model is ParakeetModel || model is WhisperKitModel {
            return downloadProgress[model.name] ?? 0.0
        }
        return 0.0
    }

    public func downloadStatus(for model: any TranscriptionModel) -> DownloadStatus {
        if let whisperModel = model as? WhisperLocalModel {
            return downloadStatuses[model.name] ?? (whisperModel.fileExists ? .downloaded : .download)
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadStatuses[model.name] ?? (parakeetModel.isDownloaded ? .downloaded : .download)
        } else if let whisperKitModel = model as? WhisperKitModel {
            return downloadStatuses[model.name] ?? (whisperKitModel.isDownloaded ? .downloaded : .download)
        }
        return .download
    }

    // MARK: - Whisper Model Download

    private func downloadWhisperModel(_ model: WhisperLocalModel) async throws {
        guard let url = model.downloadURL else {
            throw ModelDownloadError.invalidURL
        }

        await MainActor.run {
            downloadStatuses[model.name] = .downloading
        }

        try await performWhisperModelDownload(model, url)
    }

    private func performWhisperModelDownload(_ model: WhisperLocalModel, _ url: URL) async throws {
        try await downloadMainModel(model, from: url)

        if let coreMLDownloadURL = model.coreMLDownloadURL {
            try await downloadAndSetupCoreMLModel(for: model, from: coreMLDownloadURL)
        }

        await MainActor.run {
            downloadStatuses[model.name] = .downloaded
            downloadProgress.removeValue(forKey: model.name + "_main")
            downloadProgress.removeValue(forKey: model.name + "_coreml")

            // Call the callback to notify that a model was downloaded
            onModelDownloaded?(model)
        }
    }

    private func downloadMainModel(_ model: WhisperLocalModel, from url: URL) async throws {
        let progressKeyMain = model.name + "_main"
        let data = try await downloadFileWithProgress(from: url, progressKey: progressKeyMain)
        try data.write(to: model.fileURL)
    }

    private func downloadAndSetupCoreMLModel(for model: WhisperLocalModel, from url: URL) async throws {
        let progressKeyCoreML = model.name + "_coreml"
        let coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)

        let coreMLZipPath = FileManager.appDirectory(for: .models).appendingPathComponent("ggml-\(model.name)-encoder.mlmodelc.zip")
        try coreMLData.write(to: coreMLZipPath)

        try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
    }

    private func unzipAndSetupCoreMLModel(for model: WhisperLocalModel, zipPath: URL, progressKey: String) async throws {
        let coreMLDestination = FileManager.appDirectory(for: .models).appendingPathComponent("ggml-\(model.name)-encoder.mlmodelc")

        try? FileManager.default.removeItem(at: coreMLDestination)
        try Zip.unzipFile(zipPath, destination: FileManager.appDirectory(for: .models), overwrite: true, password: nil)
        try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
    }

    private func verifyAndCleanupCoreMLFiles(_ model: WhisperLocalModel, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            try? FileManager.default.removeItem(at: zipPath)
            throw ModelDownloadError.unzipFailed
        }

        try? FileManager.default.removeItem(at: zipPath)
        downloadProgress.removeValue(forKey: progressKey)
    }

    private func currentProgressForWhisper(_ model: WhisperLocalModel) -> Double {
        let mainKey = model.name + "_main"
        let coreMLKey = model.name + "_coreml"

        let mainProgress = downloadProgress[mainKey] ?? 0.0
        let coreMLProgress = downloadProgress[coreMLKey] ?? 0.0

        if model.coreMLDownloadURL != nil {
            return (mainProgress * 0.5) + (coreMLProgress * 0.5)
        } else {
            return mainProgress
        }
    }

    // MARK: - Parakeet Model Download

    private func downloadParakeetModel(_ model: ParakeetModel) async throws {
        await MainActor.run {
            downloadStatuses[model.name] = .downloading
            downloadProgress[model.name] = 0.0
        }

        logger.notice("📥 Starting download of \(model.displayName)")

        // Start progress simulation - declare outside do block to ensure cleanup
        let progressTask = Task { @MainActor in
            while !Task.isCancelled && self.downloadStatuses[model.name] == .downloading {
                if let currentProgress = self.downloadProgress[model.name], currentProgress < 0.9 {
                    self.downloadProgress[model.name] = min(currentProgress + 0.02, 0.9)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }

        // Ensure progress task is cancelled regardless of success or failure
        defer {
            progressTask.cancel()
        }

        do {
            async let asrDownload = AsrModels.downloadAndLoad(to: model.modelsDirectory, version: .v3)
            async let vadDownload = DownloadUtils.loadModels(
                .vad,
                modelNames: Array(ModelNames.VAD.requiredModels),
                directory: FileManager.appDirectory(for: .parakeetModels)
            )

            _ = try await (asrDownload, vadDownload)

            await MainActor.run {
                self.downloadProgress[model.name] = 1.0
                self.downloadStatuses[model.name] = .downloaded
                logger.notice("✅ Successfully downloaded \(model.displayName)")
            }

            try? await Task.sleep(for: .seconds(0.5))

            await MainActor.run {
                self.downloadProgress.removeValue(forKey: model.name)
                self.onModelDownloaded?(model)
            }

        } catch {
            await MainActor.run {
                self.downloadStatuses[model.name] = .download
                self.downloadProgress.removeValue(forKey: model.name)
            }

            logger.error("❌ Failed to download \(model.displayName): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - WhisperKit Model Download

    private func downloadWhisperKitModel(_ model: WhisperKitModel) async throws {
        await MainActor.run {
            downloadStatuses[model.name] = .downloading
            downloadProgress[model.name] = 0.0
        }

        logger.notice("📥 Starting download and preparation of \(model.displayName)")

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

            // Check if model needs downloading using consolidated path
            let modelFolder = WhisperKitModel.modelPath(for: model.whisperKitModelName)

            if !FileManager.default.fileExists(atPath: modelFolder.path) {
                logger.notice("📥 Downloading model: \(model.whisperKitModelName)")

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

                whisperKit.modelFolder = downloadedFolder
            } else {
                whisperKit.modelFolder = modelFolder
                await MainActor.run {
                    self.downloadProgress[model.name] = 0.7
                }
            }

            // Prewarm models (critical for first-time performance)
            logger.notice("🔥 Prewarming model: \(model.whisperKitModelName)")
            await MainActor.run {
                self.downloadProgress[model.name] = 0.75
            }

            let prewarmStart = Date()
            try await whisperKit.prewarmModels()
            let prewarmDuration = Date().timeIntervalSince(prewarmStart)
            logger.notice("✅ Model prewarmed in \(String(format: "%.2f", prewarmDuration)) seconds")

            await MainActor.run {
                self.downloadProgress[model.name] = 0.9
            }

            // Load models
            logger.notice("📚 Loading model: \(model.whisperKitModelName)")
            let loadStart = Date()
            try await whisperKit.loadModels()
            let loadDuration = Date().timeIntervalSince(loadStart)
            logger.notice("✅ Model loaded in \(String(format: "%.2f", loadDuration)) seconds")

            await MainActor.run {
                self.downloadProgress[model.name] = 1.0
                self.downloadStatuses[model.name] = .downloaded
                logger.notice("✅ Successfully downloaded and prepared \(model.displayName)")
                logger.notice("⏱️ Preparation time: prewarm: \(String(format: "%.2f", prewarmDuration))s, load: \(String(format: "%.2f", loadDuration))s")
            }

            // Unload models after download to free memory
            // They will be loaded again when needed for transcription
            await whisperKit.unloadModels()

            try? await Task.sleep(for: .seconds(0.5))

            await MainActor.run {
                self.downloadProgress.removeValue(forKey: model.name)
                self.onModelDownloaded?(model)
            }

        } catch {
            await MainActor.run {
                self.downloadStatuses[model.name] = .download
                self.downloadProgress.removeValue(forKey: model.name)
            }

            logger.error("❌ Failed to download \(model.displayName): \(error.localizedDescription)")
            throw error
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
