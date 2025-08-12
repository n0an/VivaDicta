//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsView: View {
    @Bindable var appState: AppState
    
    var body: some View {
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
        .navigationBarTitle("Models", displayMode: .inline)
    }
    
    
    func loadModel(whisperModel: WhisperModelEnum) {
        appState.loadModel(model: whisperModel)
    }
    
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsView(appState: appState)
}
