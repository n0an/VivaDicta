//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.26
//

import SwiftUI
import TipKit

struct ModelsView: View {
    @Bindable var appState: AppState
    @State var modelType: TranscriptionModelType = .local
    @State var cloudModelToConfigure: CloudModel?
    @State private var downloadManager: ModelDownloadManager
    
    @Namespace var zoomNamespace

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
                                    },
                                    onDeleteAPIKey: { cloudModel in
                                        handleAPIKeyDeletion(for: cloudModel)
                                    }
                                )
                                .matchedTransitionSource(id: cloudModel.id, in: zoomNamespace)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationDestination(item: $cloudModelToConfigure, destination: { model in
            CloudModelConfigurationView(
                model: model,
                onSave: { cloudModel in
                    cloudModelConfigured(cloudModel)
                })
            .navigationTransition(.zoom(sourceID: model.id, in: zoomNamespace))
        })
        .navigationTitle("Transcription Models")
        .navigationBarTitleDisplayMode(.large)
    }

    var filteredModels: [any TranscriptionModel] {
        switch modelType {
        case .local:
            let localModels = appState.transcriptionManager.allAvailableModels.filter { $0.provider == .parakeet || $0.provider == .whisperKit }

            // Custom ordering for local models
            let modelOrder = [
                "parakeet-tdt-0.6b-v3",
                "whisperkit-large-v3-v20240930_turbo_632MB",
                "parakeet-tdt-0.6b-v2",
                "whisperkit-large-v3-v20240930_626MB",
                "whisperkit-base",
                "whisperkit-base.en",
                "whisperkit-tiny",
                "whisperkit-tiny.en",
            ]

            return localModels.sorted { first, second in
                let firstIndex = modelOrder.firstIndex(of: first.name) ?? Int.max
                let secondIndex = modelOrder.firstIndex(of: second.name) ?? Int.max
                return firstIndex < secondIndex
            }

        case .cloud:
            return appState.transcriptionManager.allAvailableModels.filter { $0.provider != .parakeet && $0.provider != .whisperKit }
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
        
        Task {
            // Hide "Select Transcription model" tips
            await SelectTranscriptionModelTipMainView.selectModelEvent.donate()
            await SelectTranscriptionModelTipSettingsView.selectModelEvent.donate()
        }
    }

    func handleAPIKeyDeletion(for model: CloudModel) {
        // Refresh the AI service to update connected providers
        appState.aiService.refreshConnectedProviders()

        // Update cloud models to reflect the change
        appState.transcriptionManager.updateCloudModels()
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    NavigationStack {
        ModelsView(appState: appState)
    }
}
