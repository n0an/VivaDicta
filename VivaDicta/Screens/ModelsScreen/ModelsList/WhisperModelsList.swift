//
//  WhisperModelsList.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.15
//

import SwiftUI

struct WhisperModelsList: View {
    var appState: AppState
    
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
        .listStyle(.grouped)
    }
    
    func loadModel(whisperModel: WhisperModelEnum) {
        appState.createTranscriber(model: whisperModel)
    }
}

#Preview {
    @State @Previewable var appState = AppState()
    WhisperModelsList(appState: appState)
}
