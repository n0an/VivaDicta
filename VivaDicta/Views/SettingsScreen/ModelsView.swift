//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.26
//

import SwiftUI
import TipKit

struct ModelsView: View {
    @Environment(AppState.self) var appState

    @State var modelType: TranscriptionModelType = .local
    @State var cloudModelToConfigure: CloudModel?
    @State private var showCustomModelConfiguration = false

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
            .onChange(of: modelType) { _, _ in
                HapticManager.selectionChanged()
            }

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

                    // Custom Model card (always shown in cloud tab)
                    if modelType == .cloud {
                        CustomTranscriptionModelCard(
                            onConfigure: {
                                showCustomModelConfiguration = true
                            }
                        )
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
        .sheet(isPresented: $showCustomModelConfiguration) {
            AddCustomTranscriptionModelView(onSave: {
                handleCustomModelSaved()
            })
        }
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
        // Only update the default mode if API key exists (not a deletion)
        if model.apiKey != nil {
            appState.aiService.updateDefaultModeIfNeeded(provider: model.provider, modelName: model.name)

            Task {
                // Hide "Select Transcription model" tips
                await SelectTranscriptionModelTipMainView.selectModelEvent.donate()
                await SelectTranscriptionModelTipSettingsView.selectModelEvent.donate()
            }
        } else {
            // API key was deleted - handle deletion
            handleAPIKeyDeletion(for: model)
        }

        appState.transcriptionManager.updateCloudModels()
        cloudModelToConfigure = nil
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

    // MARK: - Custom Model Management

    private func handleCustomModelSaved() {
        appState.transcriptionManager.updateCloudModels()

        Task {
            // Hide "Select Transcription model" tips
            await SelectTranscriptionModelTipMainView.selectModelEvent.donate()
            await SelectTranscriptionModelTipSettingsView.selectModelEvent.donate()
        }
    }
}

#Preview {
    NavigationStack {
        ModelsView()
    }
    .environment(AppState())
}
