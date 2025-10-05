//
//  WhisperKitModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import SwiftUI

struct WhisperKitModelCard: View {
    private var model: WhisperKitModel
    private let downloadManager: ModelDownloadManager

    private var currentProgress: Double {
        downloadManager.currentProgress(for: model)
    }

    private var downloadStatus: DownloadStatus {
        downloadManager.downloadStatus(for: model)
    }

    private var isDownloaded: Bool {
        downloadStatus == .downloaded
    }

    init(model: WhisperKitModel,
         downloadManager: ModelDownloadManager) {
        self.model = model
        self.downloadManager = downloadManager
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
        .background(.gray.opacity(0.1), in: .rect(cornerRadius: 16))
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
            if isDownloaded {
                Text("Downloaded")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.5), in: .rect(cornerRadius: 16))
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
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Downloaded")
                }
                .foregroundStyle(.green)
            }
        }
    }

    var progressView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                ProgressView(value: currentProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 100)
                Text("\(Int(currentProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            Text(progressStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var progressStatusText: String {
        let progress = currentProgress
        if progress < 0.7 {
            return "Downloading model files..."
        } else if progress < 0.75 {
            return "Preparing model..."
        } else if progress < 0.9 {
            return "Optimizing for first-time use (this may take a few minutes)..."
        } else if progress < 0.95 {
            return "Loading model..."
        } else {
            return "Finalizing..."
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

    func downloadModel(_ model: WhisperKitModel) {
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
    WhisperKitModelCard(
        model: TranscriptionModelProvider.allWhisperKitModels[0],
        downloadManager: ModelDownloadManager()
    )
}
