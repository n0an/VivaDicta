//
//  WhisperModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct WhisperModelView: View {
    enum DownloadStatus: String {
        case download
        case downloading
        case downloaded
    }
    
    private var model: WhisperModelEnum
    
    @State private var downloadStatus: DownloadStatus
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progress = 0.0
    @State private var observation: NSKeyValueObservation?
    
    
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
//            download()
            Task {
                
                await downloadModel(self.model)
            }
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
    
    func downloadModel(_ model: WhisperModelEnum) async {
        guard let url = model.downloadURL else { return }
        
        do {
            try await downloadMainModel(model, from: url)
            
//            if let coreMLZipURL = whisperModel.coreMLZipDownloadURL,
//               let coreMLURL = URL(string: coreMLZipURL) {
//                try await downloadAndSetupCoreMLModel(for: whisperModel, from: coreMLURL)
//            }
            
            availableModels.append(model)
            self.downloadProgress.removeValue(forKey: model.rawValue + "_main")
        } catch {
            handleModelDownloadError(model, error)
        }
    }
    
    
    private func downloadMainModel(_ model: WhisperModelEnum, from url: URL) async throws {
        let progressKeyMain = model.rawValue + "_main"
        
//        let data = try await downloadFileWithProgress(from: url, progressKey: progressKeyMain)
        
        try await downloadFile(from: url, progressKey: progressKeyMain)

        
//        let destinationURL = modelsDirectory.appendingPathComponent(model.filename)
//        try data.write(to: destinationURL)
        
//        return WhisperModelEnum(name: model.rawValue, url: destinationURL)
    }
    
//    private func downloadFileWithProgress(from url: URL, progressKey: String) async throws -> Data {
//        let destinationURL = modelsDirectory.appendingPathComponent(UUID().uuidString)
//        
//        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
//            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
//                if let error = error {
//                    continuation.resume(throwing: error)
//                    return
//                }
//                
//                guard let httpResponse = response as? HTTPURLResponse,
//                      (200...299).contains(httpResponse.statusCode),
//                      let tempURL = tempURL else {
//                    continuation.resume(throwing: URLError(.badServerResponse))
//                    return
//                }
//                
//                do {
//                    // Move the downloaded file to the final destination
//                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
//                    
//                    // Read the file in chunks to avoid memory pressure
//                    let data = try Data(contentsOf: destinationURL, options: .mappedIfSafe)
//                    continuation.resume(returning: data)
//                    
//                    // Clean up the temporary file
//                    try? FileManager.default.removeItem(at: destinationURL)
//                } catch {
//                    continuation.resume(throwing: error)
//                }
//            }
//            
//            task.resume()
//            
//            var lastUpdateTime = Date()
//            var lastProgressValue: Double = 0
//            
//            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
//                let currentTime = Date()
//                let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)
//                let currentProgress = round(progress.fractionCompleted * 100) / 100
//                
//                if timeSinceLastUpdate >= 0.5 && abs(currentProgress - lastProgressValue) >= 0.01 {
//                    lastUpdateTime = currentTime
//                    lastProgressValue = currentProgress
//                    
//                    DispatchQueue.main.async {
//                        self.downloadProgress[progressKey] = currentProgress
//                    }
//                }
//            }
//            
//            Task {
//                await withTaskCancellationHandler {
//                    observation.invalidate()
//                } operation: {
//                    await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
//                }
//            }
//        }
//    }
    
//    private func downloadAndSetupCoreMLModel(for model: WhisperModel, from url: URL) async throws {
//        let progressKeyCoreML = model.name + "_coreml"
//        let coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)
//        
//        let coreMLZipPath = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc.zip")
//        try coreMLData.write(to: coreMLZipPath)
//        
//        try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
//    }
    
//    private func unzipAndSetupCoreMLModel(for model: WhisperModel, zipPath: URL, progressKey: String) async throws {
//        let coreMLDestination = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc")
//        
//        try? FileManager.default.removeItem(at: coreMLDestination)
//        try await unzipCoreMLFile(zipPath, to: modelsDirectory)
//        try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
//    }
    
//    private func unzipCoreMLFile(_ zipPath: URL, to destination: URL) async throws {
//        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
//            do {
//                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
//                try Zip.unzipFile(zipPath, destination: destination, overwrite: true, password: nil)
//                continuation.resume()
//            } catch {
//                continuation.resume(throwing: error)
//            }
//        }
//    }
    
//    private func verifyAndCleanupCoreMLFiles(_ model: WhisperModel, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws -> WhisperModel {
//        var model = model
//        
//        var isDirectory: ObjCBool = false
//        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
//            try? FileManager.default.removeItem(at: zipPath)
//            throw WhisperStateError.unzipFailed
//        }
//        
//        try? FileManager.default.removeItem(at: zipPath)
//        model.coreMLEncoderURL = destination
//        self.downloadProgress.removeValue(forKey: progressKey)
//        
//        return model
//    }
    
    private func handleModelDownloadError(_ model: WhisperModelEnum, _ error: Error) {
        self.downloadProgress.removeValue(forKey: model.rawValue + "_main")
        self.downloadProgress.removeValue(forKey: model.rawValue + "_coreml")
    }
    
//    func deleteModel(_ model: WhisperModel) async {
//        do {
//            // Delete main model file
//            try FileManager.default.removeItem(at: model.url)
//            
//            // Delete CoreML model if it exists
//            if let coreMLURL = model.coreMLEncoderURL {
//                try? FileManager.default.removeItem(at: coreMLURL)
//            } else {
//                // Check if there's a CoreML directory matching the model name
//                let coreMLDir = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc")
//                if FileManager.default.fileExists(atPath: coreMLDir.path) {
//                    try? FileManager.default.removeItem(at: coreMLDir)
//                }
//            }
//            
//            // Update model state
//            availableModels.removeAll { $0.id == model.id }
//            if currentTranscriptionModel?.name == model.name {
//
//                currentTranscriptionModel = nil
//                UserDefaults.standard.removeObject(forKey: "CurrentTranscriptionModel")
//
//                loadedLocalModel = nil
//                recordingState = .idle
//                UserDefaults.standard.removeObject(forKey: "CurrentModel")
//            }
//        } catch {
//            logError("Error deleting model: \(model.name)", error)
//        }
//
//        // Ensure UI reflects removal of imported models as well
//        await MainActor.run {
//            self.refreshAllAvailableModels()
//        }
//    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    private func downloadFile(from url: URL, progressKey: String) async throws {
        downloadStatus = .downloading
//        print("Downloading model \(model.rawValue) from \(model.downloadURL?.absoluteString ?? "unknown URL")")
//        guard let url = model.downloadURL else { return }
        
        downloadTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            Task { @MainActor in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }

                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                    print("Server error!")
                    return
                }

                do {
                    if let temporaryURL = temporaryURL {
                        try FileManager.default.moveItem(at: temporaryURL, to: model.fileURL)
                        print("Writing to \(model.filename) completed")
                        downloadStatus = .downloaded
                    }
                } catch let err {
                    print("Error: \(err.localizedDescription)")
                }
            }
        }

        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
            Task { @MainActor in
                self.downloadProgress[progressKey] = progress.fractionCompleted
                self.progress = progress.fractionCompleted
            }
        }

        downloadTask?.resume()
        
    }
    
    
    
    
    private func download() {
        downloadStatus = .downloading
        print("Downloading model \(model.rawValue) from \(model.downloadURL?.absoluteString ?? "unknown URL")")
        guard let url = model.downloadURL else { return }
        
        downloadTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            Task { @MainActor in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }

                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                    print("Server error!")
                    return
                }

                do {
                    if let temporaryURL = temporaryURL {
                        try FileManager.default.moveItem(at: temporaryURL, to: model.fileURL)
                        print("Writing to \(model.filename) completed")
                        downloadStatus = .downloaded
                    }
                } catch let err {
                    print("Error: \(err.localizedDescription)")
                }
            }
        }

        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
            Task { @MainActor in
                self.progress = progress.fractionCompleted
            }
        }

        downloadTask?.resume()
        
    }
}

#Preview {
    WhisperModelView(model: WhisperModelEnum.tiny, onSelect: {_ in print("select") })
}

