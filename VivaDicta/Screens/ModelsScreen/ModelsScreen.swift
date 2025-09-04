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
                Picker("Model type", selection: $modelType) {
                    ForEach(TranscriptionModelType.allCases, id: \.self) {
                        Text($0.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)
                
                switch modelType {
                case .local:
                    localModelsView
                case .cloud:
                    cloudModelsView
                }
            }
            .navigationBarTitle("Transcription Models")
            .toolbar {
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
    
    var localModelsView: some View {
        ScrollView {
            ForEach(appState.allLocalModels) { model in
                WhisperLocalModelCard(
                    model: model,
                    isSelected: model == appState.selectedLocalWhisperModel,
                    downloadManager: downloadManager,
                    onSelect: { model in
                        loadModel(whisperLocalModel: model)
                    })
            }
        }
    }
    
    var cloudModelsView: some View {
        ScrollView {
            ForEach(appState.allCloudModels) { model in
                CloudModelCard(
                    model: model,
                    isSelected: model == appState.selectedCloudModel,
                    onConfigure: { model in
                        configureCloudModel(model: model)
                    },
                    onSelect: { model in
                        loadModel(cloudModel: model)
                    })
            }
        }
        .navigationDestination(item: $cloudModelToConfigure, destination: { model in
            CloudModelConfigurationView(
                model: model,
                onSave: { (model, apiKey) in
                    cloudModelConfigured(model: model, apiKey: apiKey)
                })
        })
    }
    
    func loadModel(whisperLocalModel: WhisperLocalModel) {
        appState.setDefaultTranscriptionModel(whisperLocalModel)
//        appState.createLocalTranscriber(model: whisperLocalModel)
    }
    
    func loadModel(cloudModel: CloudModel) {
        appState.setDefaultTranscriptionModel(cloudModel)

//        appState.createCloudTranscriber(model: cloudModel)
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


