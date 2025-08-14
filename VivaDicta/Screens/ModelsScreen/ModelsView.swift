//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsView: View {
    @Bindable var appState: AppState
    
    @State var navigationPath: [TranscriptionModel] = []
    
    var body: some View {
        
        NavigationStack(path: $navigationPath) {
            VStack {
                Menu("Language", systemImage: "globe") {
                    Picker("Language", selection: $appState.selectedLanguage) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.fullName)
                                .tag(language)
                        }
                    }
                }
                .padding(.trailing, 40)
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                
                List {
                    NavigationLink("Cloud") {
                        List {
                            Section(header: Text("Cloud Models")) {
                                ForEach(CloudTranscriptionModel.allCases) { model in
                                    Text("ooo")
//                                    WhisperModelView(model: model) { model in
//                                        loadModel(whisperModel: model)
//                                    }
                                }
                            }
                        }
                        .listStyle(GroupedListStyle())
                        
                    }
                    NavigationLink("Local") {
                        List {
                            Section(header: Text("Local Whisper Models")) {
                                ForEach(WhisperModelEnum.allCases) { model in
                                    WhisperModelView(model: model) { model in
                                        loadModel(whisperModel: model)
                                    }
                                }
                            }
                        }
                        .listStyle(GroupedListStyle())
                        
                    }
                }
            }
            .navigationBarTitle("Models", displayMode: .inline)
        }
    }
    
    
    func loadModel(whisperModel: WhisperModelEnum) {
        appState.createTranscriber(model: whisperModel)
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsView(appState: appState)
}
