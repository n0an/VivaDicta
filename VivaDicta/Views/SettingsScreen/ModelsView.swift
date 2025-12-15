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

    @Namespace var zoomNamespace

    var body: some View {
        VStack(spacing: 0) {
            // Main segmented control at the top
            Picker("Model type", selection: $modelType) {
                ForEach(TranscriptionModelType.allCases) {
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
                                    downloadManager: appState.downloadManager
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
                "whisperkit-large-v3-v20240930_turbo_632MB",
                "parakeet-tdt-0.6b-v3",
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

        // Disable AI enhancement for modes using this provider
        if let aiProvider = model.provider.mappedAIProvider {
            appState.aiService.disableAIEnhancementForModesUsingProvider(aiProvider)
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    NavigationStack {
        ModelsView(appState: appState)
    }
}
