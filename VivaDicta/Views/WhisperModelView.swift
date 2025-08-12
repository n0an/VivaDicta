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
    
    private var model: WhisperModel
    @State private var downloadStatus: DownloadStatus
    
    private var onSelect: (WhisperModel) -> Void
    
    var body: some View {
        
        HStack {
            Text("\(model.name) \(model.info)")
            Spacer()
            buttons
        }
        .padding()
        
    }
    
    var buttons: some View {
        HStack {
            switch downloadStatus {
            case .download:
                downloadButton
            case .downloading:
                // Progressbar here
                EmptyView()
            case .downloaded:
                selectButton
                deleteButton
            }
        }
    }
    
    var downloadButton: some View {
        Button("Download") {
            download()
        }
        .padding(8)
        .foregroundStyle(.white)
        .background(.blue, in: .rect(cornerRadius: 8))
    }
    
    var selectButton: some View {
        Button("Select") {
            onSelect(model)
        }
        .padding(8)
        .foregroundStyle(.white)
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
        .padding(8)
        .foregroundStyle(.white)
        .background(.red, in: .rect(cornerRadius: 8))
    }
    
    init(model: WhisperModel,
         onSelect: @escaping (WhisperModel) -> Void) {
        self.model = model
        self.downloadStatus = self.model.fileExists ? .downloaded : .download
        self.onSelect = onSelect
    }
    
    private func download() {
        downloadStatus = .downloading
        print("Downloading model \(model.name) from \(model.url)")
        guard let url = URL(string: model.url) else { return }

        URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            guard let response = response as? HTTPURLResponse,
                  200...299 ~= response.statusCode else {
                print("Server error!")
                return
            }

            do {
                if let temporaryURL = temporaryURL {
                    try FileManager.default.copyItem(at: temporaryURL, to: model.fileURL)
                    print("Writing to \(model.filename) completed")
                    downloadStatus = .downloaded
                }
            } catch let err {
                print("Error: \(err.localizedDescription)")
            }
        }.resume()

//        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
//            self.progress = progress.fractionCompleted
//        }
//
//        downloadTask?.resume()
    }
}

#Preview {
    WhisperModelView(model: WhisperModel.models[0], onSelect: {_ in print("select") })
}

