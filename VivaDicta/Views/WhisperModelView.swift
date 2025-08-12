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
            download()
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
    
    private func download() {
        downloadStatus = .downloading
        print("Downloading model \(model.rawValue) from \(model.downloadURL)")
        guard let url = model.downloadURL else { return }
        
        downloadTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
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

        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
            self.progress = progress.fractionCompleted
        }

        downloadTask?.resume()
        
    }
}

#Preview {
    WhisperModelView(model: WhisperModelEnum.tiny, onSelect: {_ in print("select") })
}

