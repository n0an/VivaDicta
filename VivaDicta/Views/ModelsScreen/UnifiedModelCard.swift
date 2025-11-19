//
//  UnifiedModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import SwiftUI

struct UnifiedModelCard: View {
    let model: any TranscriptionModel
    let modelType: TranscriptionModelType
    let downloadManager: ModelDownloadManager?
    let onConfigure: ((CloudModel) -> Void)?

    @State private var selectedTab: TranscriptionModelType

    private var isWhisperKit: Bool {
        model is WhisperKitModel
    }

    private var isParakeet: Bool {
        model is ParakeetModel
    }

    private var isCloud: Bool {
        model is CloudModel
    }

    private var isDownloaded: Bool {
        if let whisperModel = model as? WhisperKitModel {
            return downloadManager?.downloadStatus(for: whisperModel) == .downloaded
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadManager?.downloadStatus(for: parakeetModel) == .downloaded
        }
        return false
    }

    private var downloadStatus: DownloadStatus {
        if let whisperModel = model as? WhisperKitModel {
            return downloadManager?.downloadStatus(for: whisperModel) ?? .download
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadManager?.downloadStatus(for: parakeetModel) ?? .download
        }
        return .download
    }

    private var currentProgress: Double {
        if let whisperModel = model as? WhisperKitModel {
            return downloadManager?.currentProgress(for: whisperModel) ?? 0
        } else if let parakeetModel = model as? ParakeetModel {
            return downloadManager?.currentProgress(for: parakeetModel) ?? 0
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
        model.name.contains("tiny") || model.name.contains("scribe-1")
    }

    private var modelSpeed: Double {
        if let whisperModel = model as? WhisperKitModel {
            return whisperModel.speed
        } else if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.speed
        } else if let cloudModel = model as? CloudModel {
            return cloudModel.speed
        }
        return 0.5
    }

    private var modelAccuracy: Double {
        if let whisperModel = model as? WhisperKitModel {
            return whisperModel.accuracy
        } else if let parakeetModel = model as? ParakeetModel {
            return parakeetModel.accuracy
        } else if let cloudModel = model as? CloudModel {
            return cloudModel.accuracy
        }
        return 0.5
    }

    private var modelLanguageDisplay: String {
        model.language
    }

    init(model: any TranscriptionModel,
         modelType: TranscriptionModelType,
         downloadManager: ModelDownloadManager? = nil,
         onConfigure: ((CloudModel) -> Void)? = nil) {
        self.model = model
        self.modelType = modelType
        self.downloadManager = downloadManager
        self.onConfigure = onConfigure
        self._selectedTab = State(initialValue: modelType)
    }

    var body: some View {
        // Model Info Section
        VStack(alignment: .leading, spacing: 20) {
            // Header with name and badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(modelLanguageDisplay)
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
//                        .background(Color(.systemGray6))
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
                
                if isCloud {
                    if let cloudModel = model as? CloudModel {
                        VStack(spacing: -8) {
                            Button(action: {
                                onConfigure?(cloudModel)
                            }) {
                                Image(systemName: "key.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 30))
                                    .frame(width: 56, height: 56)
                            }
                            Text("Add Api Key")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Local model download/status button
                    switch downloadStatus {
                    case .download:
                        Button(action: {
                            downloadLocalModel()
                        }) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 30))
                                .frame(width: 56, height: 56)
                        }
                    case .downloading:
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                    .frame(width: 56, height: 56)

                                Circle()
                                    .trim(from: 0, to: currentProgress)
                                    .stroke(Color.blue, lineWidth: 4)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 56, height: 56)

                                Text("\(Int(currentProgress * 100))%")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                    case .downloaded:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 56, height: 56)
                    }
                }
            }
            

            // Description
            Text(model.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            
        }
        .padding(20)
//        .background(Color(.systemGray6))
        .background(.white)

        .cornerRadius(20)
    }

    private func downloadLocalModel() {
        Task {
            do {
                if let whisperModel = model as? WhisperKitModel {
                    try await downloadManager?.downloadModel(whisperModel)
                } else if let parakeetModel = model as? ParakeetModel {
                    try await downloadManager?.downloadModel(parakeetModel)
                }
            } catch {
                if let whisperModel = model as? WhisperKitModel {
                    await downloadManager?.handleModelDownloadError(whisperModel, error)
                } else if let parakeetModel = model as? ParakeetModel {
                    await downloadManager?.handleModelDownloadError(parakeetModel, error)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Preview with a WhisperKit model
            if let whisperModel = TranscriptionModelProvider.allWhisperKitModels.first {
                UnifiedModelCard(
                    model: whisperModel,
                    modelType: .local,
                    downloadManager: ModelDownloadManager()
                )
            }

            // Preview with a Cloud model
            if let cloudModel = TranscriptionModelProvider.allCloudModels.first {
                UnifiedModelCard(
                    model: cloudModel,
                    modelType: .cloud,
                    onConfigure: { _ in print("Configure") }
                )
            }
        }
        .padding()
        .background(.gray)
    }
}
