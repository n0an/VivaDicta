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

    private var isRecommended: Bool {
        // Logic to determine if model is recommended
        model.name.contains("tiny") || model.name.contains("turbo")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with name and badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(model.language)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isRecommended {
                    Text("Recommended")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                }

                Spacer()

                if let size = modelSize {
                    Text(size)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6), in: .capsule)
                }
            }

            HStack(spacing: 0) {
                // Metrics Section
                VStack(spacing: 8) {
                    ModelMetricRow(
                        label: "Speed",
                        value: Int(modelSpeed * 10),
                        color: .green
                    )

                    ModelMetricRow(
                        label: "Accuracy",
                        value: Int(modelAccuracy * 10),
                        color: .orange
                    )
                }

                Spacer()

                // Local model download/status button
                
                
                Button {
                    switch downloadStatus {
                    case .download:
                        downloadLocalModel()
                    case .downloading:
                        // TODO: - add cancel method
                    case .downloaded:
                        // TODO: - add delete method

                    }
                } label: {
                    Image(systemName: downloadStatus.actionButtonImage)
                        .foregroundStyle(downloadStatus.actionButtonColor)
                        .font(.system(size: 30))
                        .frame(width: 56, height: 56)
                }
                
                
                
                
//                switch downloadStatus {
//                case .download:
//                    Button(action: {
//                        downloadLocalModel()
//                    }) {
//                        Image(systemName: "arrow.down.circle.fill")
//                            .foregroundStyle(.blue)
//                            .font(.system(size: 30))
//                            .frame(width: 56, height: 56)
//                    }
//                case .downloading:
//                    VStack(spacing: 4) {
//                        ZStack {
//                            Circle()
//                                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
//                                .frame(width: 56, height: 56)
//
//                            Circle()
//                                .trim(from: 0, to: currentProgress)
//                                .stroke(Color.blue, lineWidth: 4)
//                                .rotationEffect(.degrees(-90))
//                                .frame(width: 56, height: 56)
//
//                            Text("\(Int(currentProgress * 100))%")
//                                .font(.caption2)
//                                .fontWeight(.medium)
//                        }
//                    }
//                case .downloaded:
//                    Image(systemName: "checkmark.circle.fill")
//                        .font(.title2)
//                        .foregroundStyle(.green)
//                        .frame(width: 56, height: 56)
//                }
            }

            // Description
            Text(model.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(.white)
        .cornerRadius(20)
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
