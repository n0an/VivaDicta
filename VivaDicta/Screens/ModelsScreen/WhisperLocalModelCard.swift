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
    
    private var currentProgress: Double {
        downloadManager.currentProgress(for: model)
    }
    
    private var downloadStatus: DownloadStatus {
        downloadManager.downloadStatus(for: model)
    }
    
    private var isDownloaded: Bool {
        downloadStatus == .downloaded
    }
    
    private var onSelect: (WhisperLocalModel) -> Void
    
    private var isSelected: Bool
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                header
//                metadataSection
//                descriptionSection
//                progressSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            actionSection
        }
        .padding(16)
        .background(isSelected ? Color(UIColor.blue.withAlphaComponent(0.1)) : .white)
        
        
        
        
    }
    
    private var header: some View {
        HStack {
            Text(model.displayName)
                .font(.system(size: 13, weight: .semibold))
            
            statusBadge
            
            Spacer()
        }
    }
    
    private var statusBadge: some View {
        Group {
            if isSelected {
                Text("Default")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            } else if isDownloaded {
                Text("Downloaded")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.lightGray.withAlphaComponent(0.5)), in: .rect(cornerRadius: 16))
            }
        }
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
        
        
        
//        HStack(spacing: 8) {
//            if isSelected {
//                HStack {
//                    Image(systemName: "checkmark.circle.fill")
//                    Text("Selected")
//                }
//                .foregroundStyle(.green)
//                
//            } else if isDownloaded {
//                selectButton
//                
//            } else {
//                
//                switch downloadStatus {
//                case .download:
//                    downloadButton
//                case .downloading:
//                    progressView
//                case .downloaded:
//                    selectButton
//                }
//                
//                Button(action: downloadAction) {
//                    HStack(spacing: 4) {
//                        Text(isDownloading ? "Downloading..." : "Download")
//                            .font(.system(size: 12, weight: .medium))
//                        Image(systemName: "arrow.down.circle")
//                            .font(.system(size: 12, weight: .medium))
//                    }
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 6)
//                    .background(
//                        Capsule()
//                            .fill(Color(.controlAccentColor))
//                            .shadow(color: Color(.controlAccentColor).opacity(0.2), radius: 2, x: 0, y: 1)
//                    )
//                }
//                .buttonStyle(.plain)
//                .disabled(isDownloading)
//            }
            
//            if isDownloaded {
//                Menu {
//                    Button(action: deleteAction) {
//                        Label("Delete Model", systemImage: "trash")
//                    }
//                    
//                    Button {
//                        if let modelURL = modelURL {
//                            NSWorkspace.shared.selectFile(modelURL.path, inFileViewerRootedAtPath: "")
//                        }
//                    } label: {
//                        Label("Show in Finder", systemImage: "folder")
//                    }
//                } label: {
//                    Image(systemName: "ellipsis.circle")
//                        .font(.system(size: 14))
//                }
//                .menuStyle(.borderlessButton)
//                .menuIndicator(.hidden)
//                .frame(width: 20, height: 20)
//            }
//        }
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
         isSelected: Bool,
         downloadManager: WhisperModelDownloadManager,
         onSelect: @escaping (WhisperLocalModel) -> Void) {
        self.model = model
        self.isSelected = isSelected
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
    WhisperLocalModelCard(
        model: TranscriptionModelProvider.allLocalModels[0],
        isSelected: false,
        downloadManager: WhisperModelDownloadManager(),
        onSelect: {_ in print("select") }
    )
}

