//
//  LocalModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import SwiftUI

struct LocalModelCard: View {
    let model: any TranscriptionModel
    let downloadManager: ModelDownloadManager

    @State private var selectedTab: TranscriptionModelType = .local

    // MARK: - Cached Model Type (Performance Optimization)

    /// Cache the typed model to avoid repeated type casting in computed properties
    private enum TypedModel {
        case whisperKit(WhisperKitModel)
        case parakeet(ParakeetModel)
        case unknown
    }

    private var typedModel: TypedModel {
        if let whisperModel = model as? WhisperKitModel {
            return .whisperKit(whisperModel)
        } else if let parakeetModel = model as? ParakeetModel {
            return .parakeet(parakeetModel)
        }
        return .unknown
    }

    // MARK: - Model Properties

    private var downloadStatus: DownloadStatus {
        switch typedModel {
        case .whisperKit(let whisperModel):
            return downloadManager.downloadStatus(for: whisperModel)
        case .parakeet(let parakeetModel):
            return downloadManager.downloadStatus(for: parakeetModel)
        case .unknown:
            return .download
        }
    }

    private var currentProgress: Double {
        switch typedModel {
        case .whisperKit(let whisperModel):
            return downloadManager.currentProgress(for: whisperModel)
        case .parakeet(let parakeetModel):
            return downloadManager.currentProgress(for: parakeetModel)
        case .unknown:
            return 0
        }
    }

    private var modelSize: String? {
        switch typedModel {
        case .whisperKit(let whisperModel):
            return whisperModel.size
        case .parakeet(let parakeetModel):
            return parakeetModel.size
        case .unknown:
            return nil
        }
    }

    private var modelSpeed: Double {
        switch typedModel {
        case .whisperKit(let whisperModel):
            return whisperModel.speed
        case .parakeet(let parakeetModel):
            return parakeetModel.speed
        case .unknown:
            return 0.5
        }
    }

    private var modelAccuracy: Double {
        switch typedModel {
        case .whisperKit(let whisperModel):
            return whisperModel.accuracy
        case .parakeet(let parakeetModel):
            return parakeetModel.accuracy
        case .unknown:
            return 0.5
        }
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
                        switch downloadStatus {
                        case .download:
                            downloadLocalModel()
                        case .downloading:
                            cancelDownload()
                        case .downloaded:
                            deleteModel()
                        }
                    } label: {
                        if #available(iOS 26.0, *) {
                            Image(systemName: downloadStatus.actionButtonImage, variableValue: downloadStatus == .downloading ? currentProgress : 1)
                                .symbolVariableValueMode(.draw)
                                .foregroundStyle(downloadStatus.actionButtonColor)
                                .font(.system(size: 30))
                        } else {
                            
                            if downloadStatus == .downloading {
                                Image(systemName: "xmark")
                                    .foregroundStyle(downloadStatus.actionButtonColor)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(8)
                                    .background {
                                        Circle()
                                            .trim(from: 0, to: currentProgress)
                                            .stroke(.black, lineWidth: 3)
                                            .rotationEffect(.degrees(-90))
                                    }
                            } else {
                                Image(systemName: downloadStatus.actionButtonImage)
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .primary.opacity(0.5), radius: 2, x: 2, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.3), lineWidth: 0.5)
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
