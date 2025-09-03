//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI


enum ModelType: String, CaseIterable, Identifiable {
    var id: Self { self }
    case local
    case cloud
    
}

struct ModelsView: View {
    @Bindable var appState: AppState
    var modelTypes = ModelType.allCases
    @State var modelType: ModelType = .local
    
    @State private var downloadManager = WhisperModelDownloadManager()
    
    var localModelsView: some View {
        List {
            Section(header: Text("Local Whisper Models")) {
                ForEach(WhisperModel.allCases) { model in
                    WhisperModelView(
                        model: model,
                        downloadManager: downloadManager
                    ) { model in
                        loadModel(whisperModel: model)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
    
    var cloudModelsView: some View {
        VStack {
            Text("Cloud")
            Spacer()
        }
    }
    
    func loadModel(whisperModel: WhisperModel) {
        appState.createTranscriber(model: whisperModel)
    }
    
    var body: some View {
        
        VStack {
            Picker("Model type", selection: $modelType) {
                ForEach(modelTypes, id: \.self) {
                    Text($0.rawValue)
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
        
        
//        NavigationStack {
//            List {
//                NavigationLink(value: TranscriptionModel.cloud) {
//                    Label("Cloud", systemImage: "cloud.circle")
//                }
//                NavigationLink(value: TranscriptionModel.local) {
//                    Label("Local", systemImage: "cpu")
//                }
//            }
//            .navigationBarTitle("Models")
//            .navigationDestination(for: TranscriptionModel.self) { modelType in
//                ModelsList(appState: appState, modelType: modelType)
//            }
//            .toolbar {
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
//                
//            }
//        }
    }
    
    
    
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsView(appState: appState)
}
