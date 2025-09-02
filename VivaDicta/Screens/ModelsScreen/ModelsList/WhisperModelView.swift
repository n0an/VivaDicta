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
    
    private let downloadManager: WhisperModelDownloadManager
    
    private var currentProgress: Double {
        downloadManager.currentProgress(for: model)
    }
    
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
                selectButton
            }
        }
        .padding()
        
    }
    
    var progressView: some View {
        HStack {
            ProgressView(value: currentProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 100)
            Text("\(Int(currentProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30)
        }
    }
    
    var downloadButton: some View {
        Button("Download") {
            downloadModel(self.model)
            
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(8)
        .background(.blue, in: .rect(cornerRadius: 8))
    }
    
    var selectButton: some View {
        Button("Select") {
            onSelect(model)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(8)
        .background(.green, in: .rect(cornerRadius: 8))

    }
    
    
    init(model: WhisperModelEnum,
         downloadManager: WhisperModelDownloadManager,
         onSelect: @escaping (WhisperModelEnum) -> Void) {
        self.model = model
        self.downloadManager = downloadManager
        self.downloadStatus = self.model.fileExists ? .downloaded : .download
        self.onSelect = onSelect
    }
    
    func downloadModel(_ model: WhisperModelEnum) {
        downloadStatus = .downloading
        
        Task {
            do {
                try await downloadManager.downloadModel(model)
                await MainActor.run {
                    downloadStatus = .downloaded
                }
            } catch {
                await downloadManager.handleModelDownloadError(model, error)
                await MainActor.run {
                    downloadStatus = .download
                }
            }
        }
    }
}

#Preview {
    WhisperModelView(
        model: WhisperModelEnum.tiny, 
        downloadManager: WhisperModelDownloadManager(), 
        onSelect: {_ in print("select") }
    )
}

