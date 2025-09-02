//
//  WhisperModelDownloadManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import Foundation
import Zip

@Observable
class WhisperModelDownloadManager {
    public var downloadProgress: [String: Double] = [:]
    private var observations: [String: NSKeyValueObservation] = [:]
    
    public func downloadModel(_ model: WhisperModelEnum) async throws {
        guard let url = model.downloadURL else {
            throw WhisperDownloadError.invalidURL 
        }
        
        try await performModelDownload(model, url)
    }
    
    private func performModelDownload(_ model: WhisperModelEnum, _ url: URL) async throws {
        try await downloadMainModel(model, from: url)
        
        if let coreMLDownloadURL = model.coreMLDownloadURL {
            try await downloadAndSetupCoreMLModel(for: model, from: coreMLDownloadURL)
        }
        
        await MainActor.run {
            downloadProgress.removeValue(forKey: model.rawValue + "_main")
            downloadProgress.removeValue(forKey: model.rawValue + "_coreml")
        }
    }
    
    private func downloadMainModel(_ model: WhisperModelEnum, from url: URL) async throws {
        let progressKeyMain = model.rawValue + "_main"
        let data = try await downloadFileWithProgress(from: url, progressKey: progressKeyMain)
        try data.write(to: model.fileURL)
    }
    
    private func downloadAndSetupCoreMLModel(for model: WhisperModelEnum, from url: URL) async throws {
        let progressKeyCoreML = model.rawValue + "_coreml"
        let coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)
        
        let coreMLZipPath = URL.documentsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc.zip")
        try coreMLData.write(to: coreMLZipPath)
        
        try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
    }
    
    private func unzipAndSetupCoreMLModel(for model: WhisperModelEnum, zipPath: URL, progressKey: String) async throws {
        let coreMLDestination = URL.documentsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc")
        
        try? FileManager.default.removeItem(at: coreMLDestination)
        try Zip.unzipFile(zipPath, destination: URL.documentsDirectory, overwrite: true, password: nil)
        try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
    }
    
    private func verifyAndCleanupCoreMLFiles(_ model: WhisperModelEnum, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws {
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
            
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let currentProgress = round(progress.fractionCompleted * 100) / 100
                Task { @MainActor in
                    self.downloadProgress[progressKey] = currentProgress
                }
            }
            
            // Store observation for potential cleanup
            observations[progressKey] = observation
        }
    }
    
    func handleModelDownloadError(_ model: WhisperModelEnum, _ error: any Error) async {
        await MainActor.run {
            downloadProgress.removeValue(forKey: model.rawValue + "_main")
            downloadProgress.removeValue(forKey: model.rawValue + "_coreml")
        }
        print("Error downloading model \(model.rawValue): \(error.localizedDescription)")
    }
    
    func currentProgress(for model: WhisperModelEnum) -> Double {
        let mainKey = model.rawValue + "_main"
        let coreMLKey = model.rawValue + "_coreml"
        
        let mainProgress = downloadProgress[mainKey] ?? 0.0
        let coreMLProgress = downloadProgress[coreMLKey] ?? 0.0
        
        if model.coreMLDownloadURL != nil {
            return (mainProgress * 0.5) + (coreMLProgress * 0.5)
        } else {
            return mainProgress
        }
    }
}

enum WhisperDownloadError: Error, LocalizedError {
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
