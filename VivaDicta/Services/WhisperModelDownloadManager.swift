//
//  WhisperModelDownloadManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import Foundation
import Zip

enum DownloadStatus: String {
    case download
    case downloading
    case downloaded
}

@Observable
class WhisperModelDownloadManager: @unchecked Sendable {
    public var downloadProgress: [String: Double] = [:]
    public var downloadStatuses: [String: DownloadStatus] = [:]
    private var observations: [String: NSKeyValueObservation] = [:]
    
    public func downloadModel(_ model: WhisperLocalModel) async throws {
        guard let url = model.downloadURL else {
            throw WhisperDownloadError.invalidURL 
        }
        
        await MainActor.run {
            downloadStatuses[model.name] = .downloading
        }
        
        try await performModelDownload(model, url)
    }
    
    private func performModelDownload(_ model: WhisperLocalModel, _ url: URL) async throws {
        try await downloadMainModel(model, from: url)
        
        if let coreMLDownloadURL = model.coreMLDownloadURL {
            try await downloadAndSetupCoreMLModel(for: model, from: coreMLDownloadURL)
        }
        
        await MainActor.run {
            downloadStatuses[model.name] = .downloaded
            downloadProgress.removeValue(forKey: model.name + "_main")
            downloadProgress.removeValue(forKey: model.name + "_coreml")
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
        
        let coreMLZipPath = URL.documentsDirectory.appendingPathComponent("ggml-\(model.name)-encoder.mlmodelc.zip")
        try coreMLData.write(to: coreMLZipPath)
        
        try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
    }
    
    private func unzipAndSetupCoreMLModel(for model: WhisperLocalModel, zipPath: URL, progressKey: String) async throws {
        let coreMLDestination = URL.documentsDirectory.appendingPathComponent("ggml-\(model.name)-encoder.mlmodelc")
        
        try? FileManager.default.removeItem(at: coreMLDestination)
        try Zip.unzipFile(zipPath, destination: URL.documentsDirectory, overwrite: true, password: nil)
        try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
    }
    
    private func verifyAndCleanupCoreMLFiles(_ model: WhisperLocalModel, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            try? FileManager.default.removeItem(at: zipPath)
            throw WhisperDownloadError.unzipFailed
        }
        
        try? FileManager.default.removeItem(at: zipPath)
        downloadProgress.removeValue(forKey: progressKey)
    }
    
    private func downloadFileWithProgress(from url: URL, progressKey: String) async throws -> Data {
        let destinationURL = URL.documentsDirectory.appendingPathComponent(UUID().uuidString)
        
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
    
    func handleModelDownloadError(_ model: WhisperLocalModel, _ error: any Error) async {
        await MainActor.run {
            downloadStatuses[model.name] = .download
            downloadProgress.removeValue(forKey: model.name + "_main")
            downloadProgress.removeValue(forKey: model.name + "_coreml")
        }
        print("Error downloading model \(model.name): \(error.localizedDescription)")
    }
    
    func currentProgress(for model: WhisperLocalModel) -> Double {
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
    
    func downloadStatus(for model: WhisperLocalModel) -> DownloadStatus {
        return downloadStatuses[model.name] ?? (model.fileExists ? .downloaded : .download)
    }
}

enum WhisperDownloadError: LocalizedError {
    case invalidURL
    case unzipFailed
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .unzipFailed:
            return "Failed to unzip CoreML model"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}
