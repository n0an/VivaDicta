//
//  DownloadButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 12.08.2025.
//

import SwiftUI

struct DownloadButton: View {
    enum DownloadStatus: String {
        case download
        case downloading
        case downloaded
    }
    private var model: WhisperModel

    @State private var status: DownloadStatus

    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progress = 0.0
    @State private var observation: NSKeyValueObservation?

    private var onLoad: ((_ model: WhisperModel) -> Void)?

    init(model: WhisperModel) {
        self.model = model
        status = model.fileExists ? DownloadStatus.downloaded : .download
    }

    func onLoad(perform action: @escaping (_ model: WhisperModel) -> Void) -> DownloadButton {
        var button = self
        button.onLoad = action
        return button
    }

    private func download() {
        status = .downloading
        print("Downloading model \(model.name) from \(model.url)")
        guard let url = URL(string: model.url) else { return }

        downloadTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
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
                    status = .downloaded
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

    var body: some View {
        VStack {
            
            Button {
                
                switch status {
                case .download:
                    download()
                case .downloading:
                    downloadTask?.cancel()
                    status = .download
                case .downloaded:
                    if !model.fileExists {
                        download()
                    }
                    onLoad?(model)
                }
                
                
            } label: {
                let title = "\(model.name) \(model.info)"
                switch status {
                case .download:
                    Text("Download \(title)")
                case .downloading:
                    Text("\(title) (Downloading \(Int(progress * 100))%)")
                case .downloaded:
                    Text("Load \(title)")
                }
            }
            .swipeActions {
                if status == .downloaded {
                    Button("Delete", role: .destructive) {
                        do {
                            try FileManager.default.removeItem(at: model.fileURL)
                        } catch {
                            print("Error deleting file: \(error)")
                        }
                        status = .download
                    }
                    .tint(.red)
                }
            }
        }
        .onDisappear() {
            downloadTask?.cancel()
        }
    }
}
