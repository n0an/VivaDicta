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
            if let whisperModel = model as? WhisperLocalModel {
                appState?.aiService.updateDefaultModeIfNeeded(provider: .local, modelName: whisperModel.name)
            } else if let parakeetModel = model as? ParakeetModel {
                appState?.aiService.updateDefaultModeIfNeeded(provider: .parakeet, modelName: parakeetModel.name)
            }
        }
        self._downloadManager = State(initialValue: manager)
    }

    var body: some View {
        VStack {
            Picker("Model type", selection: $modelType) {
                ForEach(TranscriptionModelType.allCases, id: \.self) {
                    Text($0.rawValue.capitalized)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ScrollView {
                ForEach(filteredModels, id: \.id) { model in
                    if let model = model as? WhisperLocalModel {
                        WhisperLocalModelCard(
                            model: model,
                            downloadManager: downloadManager)
                    } else if let model = model as? ParakeetModel {
                        ParakeetModelCard(
                            model: model,
                            downloadManager: downloadManager)
                    } else if let model = model as? CloudModel {
                        CloudModelCard(
                            model: model,
                            onConfigure: { model in
                                configureCloudModel(model: model)
                            })
                    }
                }
            }
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
    }

    var filteredModels: [any TranscriptionModel] {
        switch modelType {
        case .local:
            appState.transcriptionManager.allAvailableModels.filter { $0.provider == .local || $0.provider == .parakeet }
        case .cloud:
            appState.transcriptionManager.allAvailableModels.filter { $0.provider != .local && $0.provider != .parakeet }
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