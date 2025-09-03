//
//  ModelsScreen.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsScreen: View {
    @Bindable var appState: AppState
    var modelTypes = TranscriptionModelType.allCases
    @State var modelType: TranscriptionModelType = .local
    
    @State private var downloadManager = WhisperModelDownloadManager()
    
    var body: some View {
        
        NavigationStack {
            VStack {
                Picker("Model type", selection: $modelType) {
                    ForEach(modelTypes, id: \.self) {
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
                ToolbarItem {
                    Menu("Language", systemImage: "globe") {
                        Picker("Language", selection: $appState.selectedLanguage) {
                            ForEach(Language.allCases, id: \.self) { language in
                                Text(language.fullName)
                                    .tag(language)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var localModelsView: some View {
        ScrollView {
            ForEach(TranscriptionModelProvider.allLocalModels) { model in
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
            ForEach(TranscriptionModelProvider.allCloudModels) { model in
                CloudModelCard(
                    model: model,
                    isSelected: model == appState.selectedCloudModel,
                    onConfigure: { model in
                        
                    },
                    onSelect: { model in
                        loadModel(cloudModel: model)
                    })
            }
        }
    }
    
    func loadModel(whisperLocalModel: WhisperLocalModel) {
        appState.createLocalTranscriber(model: whisperLocalModel)
    }
    
    func loadModel(cloudModel: CloudModel) {
        appState.createCloudTranscriber(model: cloudModel)
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsScreen(appState: appState)
}
