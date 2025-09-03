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
        List {
            Section(header: Text("Local Whisper Transcription Models")) {
                ForEach(TranscriptionModelProvider.allLocalModels) { model in
                    WhisperLocalModelCard(
                        model: model,
                        downloadManager: downloadManager
                    ) { model in
                        loadModel(whisperLocalModel: model)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
    
    var cloudModelsView: some View {
        List {
            Section(header: Text("Cloud Transcription Models")) {
                ForEach(TranscriptionModelProvider.allCloudModels) { model in
                    Text(model.displayName)
                    
                }
            }
        }
        .listStyle(.grouped)
    }
    
    func loadModel(whisperLocalModel: WhisperLocalModel) {
        appState.createTranscriber(model: whisperLocalModel)
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsScreen(appState: appState)
}
