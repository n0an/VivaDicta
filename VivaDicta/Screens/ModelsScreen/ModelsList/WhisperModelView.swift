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
                try await downloadMainModel(model, from: url)
                
                if let coreMLDownloadURL = model.coreMLDownloadURL {
                    try await downloadAndPrepareCoreMLFile(from: coreMLDownloadURL, progressKey: model.rawValue + "_coreml")
                }
                
//                availableModels.append(model)
//                self.downloadProgress.removeValue(forKey: model.rawValue + "_main")
            } catch {
                handleModelDownloadError(model, error)
            }
        }
        
    }
    
    
    private func downloadMainModel(_ model: WhisperModelEnum, from url: URL) async throws {
        let progressKeyMain = model.rawValue + "_main"
        
        
        try await downloadFile(from: url, progressKey: progressKeyMain)

    }
    
    private func unzipAndSetupCoreMLModel(for model: WhisperModelEnum, zipPath: URL, progressKey: String) async throws {
        let coreMLDestination = URL.documentsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc")
        
        try? FileManager.default.removeItem(at: coreMLDestination)
        try await unzipCoreMLFile(zipPath, to: coreMLDestination)
        try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
    }
    
    private func unzipCoreMLFile(_ zipPath: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
//                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try Zip.unzipFile(zipPath, destination: destination, overwrite: true, password: nil)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func verifyAndCleanupCoreMLFiles(_ model: WhisperModelEnum, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws {
//        var model = model
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            try? FileManager.default.removeItem(at: zipPath)
            throw WhisperStateError.unzipFailed
        }
        
        try? FileManager.default.removeItem(at: zipPath)
//        model.coreMLEncoderURL = destination
        self.downloadProgress.removeValue(forKey: progressKey)
        
//        return model
    }
    
    private func handleModelDownloadError(_ model: WhisperModelEnum, _ error: any Error) {
        self.downloadProgress.removeValue(forKey: model.rawValue + "_main")
        self.downloadProgress.removeValue(forKey: model.rawValue + "_coreml")
    }
    
    
    
    
    
    
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
    
    private func downloadAndPrepareCoreMLFile(from url: URL, progressKey: String) async throws {
        downloadStatus = .downloading
//        print("Downloading model \(model.rawValue) from \(model.downloadURL?.absoluteString ?? "unknown URL")")
//        guard let url = model.downloadURL else { return }
        
        downloadCoreMLModelTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            Task { @MainActor in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }

                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                    print("Server error!")
                    return
                }
                
                
//                
////                let coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)
//                guard let temporaryURL else { return }
//                let coreMLData = Data(contentsOf: temporaryURL)
//                
//                let coreMLZipPath = modelsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc.zip")
//                try coreMLData.write(to: coreMLZipPath)
//                
//                try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
                
                
                

                do {
                    if let temporaryURL = temporaryURL {
                        let coreMLZipPath = URL.documentsDirectory.appendingPathComponent("\(model.rawValue)-encoder.mlmodelc.zip")

                        try FileManager.default.moveItem(at: temporaryURL, to: coreMLZipPath)
                        
                        print("Writing coreml zip to \(model.filename) completed")
                        
                        try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKey)

                        
                        downloadStatus = .downloaded
                    }
                } catch let err {
                    print("Error: \(err.localizedDescription)")
                }
            }
        }

        observationCoreMLModel = downloadCoreMLModelTask?.progress.observe(\.fractionCompleted) { progress, _ in
            Task { @MainActor in
                self.downloadProgress[progressKey] = progress.fractionCompleted
                self.progress = progress.fractionCompleted
            }
        }

        downloadCoreMLModelTask?.resume()
        
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

