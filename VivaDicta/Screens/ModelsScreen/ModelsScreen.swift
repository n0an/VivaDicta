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
    @State private var downloadManager = WhisperModelDownloadManager()
    
    var body: some View {
        
        NavigationStack {
            VStack {
                
                LanguageSelectionMenu(appState: appState)
                
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
                                isSelected: model.name == appState.currentTranscriptionModel?.name,
                                downloadManager: downloadManager,
                                onSelect: { model in
                                    loadModel(whisperLocalModel: model)
                                })
                        } else if let model = model as? CloudModel {
                            CloudModelCard(
                                model: model,
                                isSelected: model.name == appState.currentTranscriptionModel?.name,
                                onConfigure: { model in
                                    configureCloudModel(model: model)
                                },
                                onSelect: { model in
                                    loadModel(cloudModel: model)
                                })
                        }
                    }
                }
            }
            .navigationDestination(item: $cloudModelToConfigure, destination: { model in
                CloudModelConfigurationView(
                    model: model,
                    onSave: { (model, apiKey) in
                        cloudModelConfigured(model: model, apiKey: apiKey)
                    })
            })
            .navigationTitle("Transcription Models")
            .toolbar {
//                LanguageSelectionMenu(appState: appState)
//                ToolbarItem {
//                    Menu("Language", systemImage: "globe") {
//                        Picker("Language", selection: $appState.selectedLanguage) {
//                            ForEach(Language.allCases, id: \.self) { language in
//                                Text(language.fullName)
//                                    .tag(language)
//                            }
//                        }
//                    }
//                }
            }
        }
    }
    
    var filteredModels: [any TranscriptionModel] {
        switch modelType {
        case .local:
            appState.allAvailableModels.filter { $0.provider == .local }
        case .cloud:
            appState.allAvailableModels.filter { $0.provider != .local }
        }
    }
    
    func loadModel(whisperLocalModel: WhisperLocalModel) {
        appState.setDefaultTranscriptionModel(whisperLocalModel)
    }
    
    func loadModel(cloudModel: CloudModel) {
        appState.setDefaultTranscriptionModel(cloudModel)
    }
    
    func configureCloudModel(model: CloudModel) {
        cloudModelToConfigure = model
    }
    
    func cloudModelConfigured(model: CloudModel, apiKey: String) {
        appState.updateCloudModels(with: model, apiKey: apiKey)
        cloudModelToConfigure = nil
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsScreen(appState: appState)
}


