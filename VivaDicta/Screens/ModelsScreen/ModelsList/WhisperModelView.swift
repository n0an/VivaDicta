//
//  WhisperModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI
import Zip

struct WhisperModelView: View {
    enum DownloadStatus: String {
        case download
        case downloading
        case downloaded
    }
    
    private var model: WhisperModelEnum
    
    @State private var downloadStatus: DownloadStatus
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var downloadCoreMLModelTask: URLSessionDownloadTask?
    @State private var progress = 0.0
    @State private var observation: NSKeyValueObservation?
    @State private var observationCoreMLModel: NSKeyValueObservation?
    
    
    @State var availableModels: [WhisperModelEnum] = []
    
    @State var downloadProgress: [String: Double] = [:]
    
    let modelsDirectory: URL = URL.documentsDirectory.appendingPathComponent("WhisperModels")
    
    private var onSelect: (WhisperModelEnum) -> Void
    
    var body: some View {
        
        HStack {
            Text("\(model.rawValue) \(model.info)")
            Spacer()
            switch downloadStatus {
            case .download:
                downloadButton
            case .downloading:
                progressView
            case .downloaded:
                HStack {
                    selectButton
//                    deleteButton
                }
            }
        }
        .padding()
        
    }
    
    var progressView: some View {
        HStack {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 100)
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30)
        }
    }
    
    var downloadButton: some View {
        Button("Download") {
            downloadModel(self.model)
            
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.blue, in: .rect(cornerRadius: 8))
    }
    
    var selectButton: some View {
        Button("Select") {
            onSelect(model)
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.green, in: .rect(cornerRadius: 8))

    }
    
    var deleteButton: some View {
        Button("Delete", role: .destructive) {
            print("Delete")
            do {
                try FileManager.default.removeItem(at: model.fileURL)
            } catch {
                print("Error deleting file: \(error)")
            }
            downloadStatus = .download
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.red, in: .rect(cornerRadius: 8))
    }
    
    init(model: WhisperModelEnum,
         onSelect: @escaping (WhisperModelEnum) -> Void) {
        self.model = model
        self.downloadStatus = self.model.fileExists ? .downloaded : .download
        self.onSelect = onSelect
    }
    
    func downloadModel(_ model: WhisperModelEnum) {
        guard let url = model.downloadURL else { return }
        
        Task {
            do {
                try await performModelDownload(model, url)
            } catch {
                await handleModelDownloadError(model, error)
            }
        }
    }
    
    
    private func performModelDownload(_ model: WhisperModelEnum, _ url: URL) async throws {
        _ = try await downloadMainModel(model, from: url)
        
        if let coreMLDownloadURL = model.coreMLDownloadURL {
            try await downloadAndSetupCoreMLModel(for: model, from: coreMLDownloadURL)
        }
        
        await MainActor.run {
            downloadStatus = .downloaded
            downloadProgress.removeValue(forKey: model.rawValue + "_main")
            downloadProgress.removeValue(forKey: model.rawValue + "_coreml")
        }
    }
    
    private func downloadMainModel(_ model: WhisperModelEnum, from url: URL) async throws -> Data {
        let progressKeyMain = model.rawValue + "_main"
        let data = try await downloadFileWithProgress(from: url, progressKey: progressKeyMain)
        try data.write(to: model.fileURL)
        return data
    }
    
    private func unzipAndSetupCoreMLModel(for model: WhisperModelEnum, zipPath: URL, progressKey: String) async throws {
        let coreMLDestination = URL.documentsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc")
        
        try? FileManager.default.removeItem(at: coreMLDestination)
        try await unzipCoreMLFile(zipPath, to: URL.documentsDirectory)
        try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
    }
    
    private func unzipCoreMLFile(_ zipPath: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
                try Zip.unzipFile(zipPath, destination: destination, overwrite: true, password: nil)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func verifyAndCleanupCoreMLFiles(_ model: WhisperModelEnum, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            try? FileManager.default.removeItem(at: zipPath)
            throw WhisperStateError.unzipFailed
        }
        
        try? FileManager.default.removeItem(at: zipPath)
        downloadProgress.removeValue(forKey: progressKey)
    }
    
    private func handleModelDownloadError(_ model: WhisperModelEnum, _ error: any Error) async {
        await MainActor.run {
            downloadStatus = .download
            downloadProgress.removeValue(forKey: model.rawValue + "_main")
            downloadProgress.removeValue(forKey: model.rawValue + "_coreml")
        }
        print("Error downloading model \(model.rawValue): \(error.localizedDescription)")
    }
    
    
    
    
    
    
    private func downloadFileWithProgress(from url: URL, progressKey: String) async throws -> Data {
        await MainActor.run {
            downloadStatus = .downloading
        }
        
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
            
            observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let currentProgress = round(progress.fractionCompleted * 100) / 100
                Task { @MainActor in
                    self.downloadProgress[progressKey] = currentProgress
                    self.progress = currentProgress
                }
            }
        }
    }
    
    private func downloadAndSetupCoreMLModel(for model: WhisperModelEnum, from url: URL) async throws {
        let progressKeyCoreML = model.rawValue + "_coreml"
        let coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)
        
        let coreMLZipPath = URL.documentsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc.zip")
        try coreMLData.write(to: coreMLZipPath)
        
        try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
    }
}

#Preview {
    WhisperModelView(model: WhisperModelEnum.tiny, onSelect: {_ in print("select") })
}

