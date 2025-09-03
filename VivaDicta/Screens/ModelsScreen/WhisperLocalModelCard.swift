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
                metadataSection
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
    
    private var metadataSection: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(model.language, systemImage: "globe")
                    .foregroundStyle(.secondary)
                Label(model.size, systemImage: "internaldrive")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            
            HStack(spacing: 3) {
                Text("Speed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ModelPerformanceStatsDots(value: model.speed * 10)
            }
            
            HStack(spacing: 3) {
                Text("Accuracy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ModelPerformanceStatsDots(value: model.accuracy * 10)
            }
            
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


struct ModelPerformanceStatsDots: View {
    var value: Double
    
    var body: some View {
        HStack(spacing: 8) {
            progressDots(value: value)
            Text(String(format: "%.1f", value))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    func progressDots(value: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 5) { index in
                Circle()
                    .fill(index < Int(value / 2) ? performanceColor(value: value / 10) : .gray)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    func performanceColor(value: Double) -> Color {
        switch value {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
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

