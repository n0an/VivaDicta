//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.26
//

import SwiftUI

struct ModelsView: View {
    @Bindable var appState: AppState
    @State var modelType: TranscriptionModelType = .local
    @State var cloudModelToConfigure: CloudModel?
    @State private var downloadManager: ModelDownloadManager

    init(appState: AppState) {
        self.appState = appState
        let manager = ModelDownloadManager()
        manager.onModelDownloaded = { [weak appState] model in
            // Update the default mode if it doesn't have a model yet
            if let parakeetModel = model as? ParakeetModel {
                appState?.aiService.updateDefaultModeIfNeeded(provider: .parakeet, modelName: parakeetModel.name)
            } else if let whisperKitModel = model as? WhisperKitModel {
                appState?.aiService.updateDefaultModeIfNeeded(provider: .whisperKit, modelName: whisperKitModel.name)
            }
        }
        self._downloadManager = State(initialValue: manager)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main segmented control at the top
            Picker("Model type", selection: $modelType) {
                ForEach(TranscriptionModelType.allCases, id: \.self) {
                    Text($0.rawValue.capitalized)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(filteredModels, id: \.id) { model in
                        Group {
                            if modelType == .local {
                                LocalModelCard(
                                    model: model,
                                    downloadManager: downloadManager
                                )
                            } else if let cloudModel = model as? CloudModel {
                                CloudModelCard(
                                    model: cloudModel,
                                    onConfigure: { cloudModel in
                                        configureCloudModel(model: cloudModel)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
        .navigationDestination(item: $cloudModelToConfigure, destination: { model in
            CloudModelConfigurationView(
                model: model,
                onSave: { cloudModel in
                    cloudModelConfigured(cloudModel)
                })
        })
        .navigationTitle("Transcription Models")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    var filteredModels: [any TranscriptionModel] {
        switch modelType {
        case .local:
            appState.transcriptionManager.allAvailableModels.filter { $0.provider == .parakeet || $0.provider == .whisperKit }
        case .cloud:
            appState.transcriptionManager.allAvailableModels.filter { $0.provider != .parakeet && $0.provider != .whisperKit }
        }
    }

    func configureCloudModel(model: CloudModel) {
        cloudModelToConfigure = model
    }

    func cloudModelConfigured(_ model: CloudModel) {
        // Update the default mode if it doesn't have a model yet
        appState.aiService.updateDefaultModeIfNeeded(provider: model.provider, modelName: model.name)
        appState.transcriptionManager.updateCloudModels()
        cloudModelToConfigure = nil
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    NavigationStack {
        ModelsView(appState: appState)
    }
}
