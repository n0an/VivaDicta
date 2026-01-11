//
//  LocalModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import SwiftUI
import TipKit

struct LocalModelCard: View {
    let model: any TranscriptionModel
    let downloadManager: ModelDownloadManager

    @State private var selectedTab: TranscriptionModelType = .local
    @State private var showDownloadAlert = false
    @State private var showDeleteAlert = false

    private var isWhisperKit: Bool {
        model is WhisperKitModel
    }

    private var isParakeet: Bool {
        model is ParakeetModel
    }

    private var isDownloaded: Bool {
        if let whisperModel = model as? WhisperKitModel {
            return downloadManager.downloadStatus(for: whisperModel) == .downloaded
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadManager.downloadStatus(for: parakeetModel) == .downloaded
        }
        return false
    }

    private var downloadStatus: DownloadStatus {
        if let whisperModel = model as? WhisperKitModel {
            return downloadManager.downloadStatus(for: whisperModel)
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadManager.downloadStatus(for: parakeetModel)
        }
        return .download
    }
    

    private var currentProgress: Double {
        if let whisperModel = model as? WhisperKitModel {
            return downloadManager.currentProgress(for: whisperModel)
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadManager.currentProgress(for: parakeetModel)
        }
        return 0
    }

    private var modelSize: String? {
        if let whisperModel = model as? WhisperKitModel {
            return whisperModel.size
        } else if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.size
        }
        return nil
    }
    
    private var modelSpeed: Double {
        if let whisperModel = model as? WhisperKitModel {
            return whisperModel.speed
        } else if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.speed
        }
        return 0.5
    }

    private var modelAccuracy: Double {
        if let whisperModel = model as? WhisperKitModel {
            return whisperModel.accuracy
        } else if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.accuracy
        }
        return 0.5
    }

    private var speedColor: Color {
        if modelSpeed >= 0.75 {
            return .green  // good
        } else if modelSpeed >= 0.6 {
            return .orange  // medium
        } else {
            return .red  // bad
        }
    }

    private var accuracyColor: Color {
        if modelAccuracy >= 0.75 {
            return .green  // good
        } else if modelAccuracy >= 0.6 {
            return .orange  // medium
        } else {
            return .red  // bad
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Label(model.language, systemImage: "globe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if model.recommended {
                        Text("Recommended")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                    }
                }

                
                Spacer()

                HStack(spacing: 8) {
                    if let size = modelSize {
                        Label(size, systemImage: "internaldrive")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.systemGray6), in: .capsule)
                    }
                    
                    
                    Button {
                        HapticManager.lightImpact()
                        switch downloadStatus {
                        case .download:
                            showDownloadAlert = true
                        case .downloading:
                            cancelDownload()
                        case .downloaded:
                            showDeleteAlert = true
                        }
                    } label: {
                        if #available(iOS 26.0, *) {
                            Image(systemName: downloadStatus.actionButtonImage, variableValue: downloadStatus == .downloading ? currentProgress : 1)
                                .symbolVariableValueMode(.draw)
                                .contentTransition(.symbolEffect(.replace))
                                .foregroundStyle(downloadStatus.actionButtonColor)
                                .font(.system(size: 30))
                        } else {
                            
                            if downloadStatus == .downloading {
                                Image(systemName: "xmark")
                                    .contentTransition(.symbolEffect(.replace))
                                    .foregroundStyle(downloadStatus.actionButtonColor)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(8)
                                    .background {
                                        // TODO: Use ProgressView with style .circular
                                        Circle()
                                            .trim(from: 0, to: currentProgress)
                                            .stroke(.black, lineWidth: 3)
                                            .rotationEffect(.degrees(-90))
                                    }
                            } else {
                                Image(systemName: downloadStatus.actionButtonImage)
                                    .contentTransition(.symbolEffect(.replace))
                                    .foregroundStyle(downloadStatus.actionButtonColor)
                                    .font(.system(size: 30))
                            }
                            
                        }
                    }
                }
            }

            // Metrics Section
            VStack(alignment: .leading, spacing: 8) {
                ModelMetricRow(
                    label: "Speed",
                    value: modelSpeed * 10,
                    color: speedColor
                )

                ModelMetricRow(
                    label: "Accuracy",
                    value: modelAccuracy * 10,
                    color: accuracyColor
                )
            }

            // Description
            Text(model.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .shadow(color: .primary.opacity(0.5), radius: 2, x: 2, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.3), lineWidth: 0.5)
        }
        .contextMenu {
            if isDownloaded {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Model", systemImage: "trash")
                }
            }
        }
        .alert("Download Model", isPresented: $showDownloadAlert) {
            Button("Continue") {
                downloadLocalModel()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Downloading and preparing the model can take up to 4 minutes. Please don't close the app while it's downloading.")
        }
        .alert("Delete Model", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteModel()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(model.displayName)? You can download it again later.")
        }
    }

    private func downloadLocalModel() {
        
        Task {
            do {
                if let whisperModel = model as? WhisperKitModel {
                    try await downloadManager.downloadModel(whisperModel)
                } else if let parakeetModel = model as? ParakeetModel {
                    try await downloadManager.downloadModel(parakeetModel)
                }

                HapticManager.heavyImpact()

                // Hide "Select Transcription model" tips
                await SelectTranscriptionModelTipMainView.selectModelEvent.donate()
                await SelectTranscriptionModelTipSettingsView.selectModelEvent.donate()

            } catch is CancellationError {
                // Don't treat cancellation as an error - it was intentional
                // Status is already reset by cancelDownload()
            } catch {
                if let whisperModel = model as? WhisperKitModel {
                    await downloadManager.handleModelDownloadError(whisperModel, error)
                } else if let parakeetModel = model as? ParakeetModel {
                    await downloadManager.handleModelDownloadError(parakeetModel, error)
                }
            }
        }
    }

    private func cancelDownload() {
        downloadManager.cancelDownload(for: model)
    }

    private func deleteModel() {
        HapticManager.warning()
        Task {
            do {
                try await downloadManager.deleteModel(model)
            } catch {
                print("Error deleting model: \(error)")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview with a WhisperKit model
        if let whisperModel = TranscriptionModelProvider.allWhisperKitModels.first {
            LocalModelCard(
                model: whisperModel,
                downloadManager: ModelDownloadManager()
            )
        }

        // Preview with a Parakeet model if available
        if let parakeetModel = TranscriptionModelProvider.allParakeetModels.first {
            LocalModelCard(
                model: parakeetModel,
                downloadManager: ModelDownloadManager()
            )
        }
    }
    .padding()
    .background(.gray)
}
