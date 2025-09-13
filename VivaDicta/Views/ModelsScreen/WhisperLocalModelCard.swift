//
//  WhisperLocalModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct WhisperLocalModelCard: View {
    private var model: WhisperLocalModel
    private let downloadManager: WhisperModelDownloadManager
    private var onSelect: (WhisperLocalModel) -> Void
    private var isSelected: Bool
    
    private var currentProgress: Double {
        downloadManager.currentProgress(for: model)
    }
    
    private var downloadStatus: DownloadStatus {
        downloadManager.downloadStatus(for: model)
    }
    
    private var isDownloaded: Bool {
        downloadStatus == .downloaded
    }
    
    init(model: WhisperLocalModel,
         isSelected: Bool,
         downloadManager: WhisperModelDownloadManager,
         onSelect: @escaping (WhisperLocalModel) -> Void) {
        self.model = model
        self.isSelected = isSelected
        self.downloadManager = downloadManager
        self.onSelect = onSelect
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    metadataSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                actionSection
            }
            descriptionSection
        }
        .padding(16)
        .background(isSelected ? Color(UIColor.blue.withAlphaComponent(0.1)) : .white, in: .rect(cornerRadius: 16))
    }
    
    private var header: some View {
        HStack {
            Text(model.displayName)
                .font(.headline.weight(.semibold))
            statusBadge
            Spacer()
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                
                HStack(spacing: 4) {
                    Text(model.language)
                    Image(systemName: "globe")
                }
                
                HStack(spacing: 4) {
                    Text(model.size)
                    Image(systemName: "internaldrive")
                }
            }
            .foregroundStyle(.secondary)
            .font(.caption)
            
            HStack(spacing: 3) {
                Text("Speed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ModelPerformanceStatsDots(value: model.speed * 10)
            }
            
            HStack(spacing: 3) {
                Text("Accuracy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ModelPerformanceStatsDots(value: model.accuracy * 10)
            }
        }
    }
    
    private var statusBadge: some View {
        Group {
            if isSelected {
                Text("Default")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            } else if isDownloaded {
                Text("Downloaded")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.lightGray.withAlphaComponent(0.5)), in: .rect(cornerRadius: 16))
            }
        }
    }
    
    private var descriptionSection: some View {
        Text(model.description)
            .multilineTextAlignment(.leading)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
    
    private var actionSection: some View {
        VStack {
            switch downloadStatus {
            case .download:
                downloadButton
            case .downloading:
                progressView
            case .downloaded:
                
                if isSelected {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Selected")
                    }
                    .foregroundStyle(.green)
                    
                } else {
                    selectButton
                }
            }
        }
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
    WhisperLocalModelCard(
        model: TranscriptionModelProvider.allLocalModels[0],
        isSelected: false,
        downloadManager: WhisperModelDownloadManager(),
        onSelect: {_ in print("select") }
    )
}

