//
//  WhisperModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct WhisperModelCard: View {
    private var model: WhisperLocalModel
    private let downloadManager: WhisperModelDownloadManager
    
    private var currentProgress: Double {
        downloadManager.currentProgress(for: model)
    }
    
    private var downloadStatus: DownloadStatus {
        downloadManager.downloadStatus(for: model)
    }
    
    private var onSelect: (WhisperLocalModel) -> Void
    
    var body: some View {
        
        HStack {
            Text("\(model.name)")
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
    
    
    init(model: WhisperLocalModel,
         downloadManager: WhisperModelDownloadManager,
         onSelect: @escaping (WhisperLocalModel) -> Void) {
        self.model = model
        self.downloadManager = downloadManager
        self.onSelect = onSelect
    }
    
    func downloadModel(_ model: WhisperLocalModel) {
        Task {
            do {
                try await downloadManager.downloadModel(model)
            } catch {
                await downloadManager.handleModelDownloadError(model, error)
            }
        }
    }
}

#Preview {
    WhisperModelCard(
        model: TranscriptionModelProvider.allLocalModels[0],
        downloadManager: WhisperModelDownloadManager(),
        onSelect: {_ in print("select") }
    )
}

