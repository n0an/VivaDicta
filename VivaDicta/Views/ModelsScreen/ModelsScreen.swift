//
//  ModelsScreen.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsScreen: View {
    @Bindable var appState: AppState
    @State var modelType: TranscriptionModelType = .local
    @State var cloudModelToConfigure: CloudModel?
    @State private var downloadManager: WhisperModelDownloadManager

    init(appState: AppState) {
        self.appState = appState
        let manager = WhisperModelDownloadManager()
        manager.onModelDownloaded = { model in
            // Update the default mode if it doesn't have a model yet
            appState.aiService.updateDefaultModeIfNeeded(provider: .local, modelName: model.name)
        }
        self._downloadManager = State(initialValue: manager)
    }

    var body: some View {

        NavigationStack {
            VStack {
                Picker("Model type", selection: $modelType) {
                    ForEach(TranscriptionModelType.allCases, id: \.self) {
                        Text($0.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)


                ScrollView {
                    ForEach(filteredModels, id: \.id) { model in
                        if let model = model as? WhisperLocalModel {
                            WhisperLocalModelCard(
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
            .navigationTitle("Model Management")
        }
    }
    
    var filteredModels: [any TranscriptionModel] {
        switch modelType {
        case .local:
            appState.transcriptionManager.allAvailableModels.filter { $0.provider == .local }
        case .cloud:
            appState.transcriptionManager.allAvailableModels.filter { $0.provider != .local }
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
    ModelsScreen(appState: appState)
}


