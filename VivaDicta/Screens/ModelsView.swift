//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI


struct ModelsView: View {
    @Bindable var appState: AppState
    
//    @State var selectedLanguage: Language = .en
    
    var body: some View {
        
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
        
        
        .navigationBarTitle("Models", displayMode: .inline)
    }
    
    
    func loadModel(whisperModel: WhisperModelEnum) {
//        appState.loadModel(model: whisperModel)
//        appState.selectedLocalWhisperModel = whisperModel
        appState.createTranscriber(model: whisperModel)
    }
    
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsView(appState: appState)
}
