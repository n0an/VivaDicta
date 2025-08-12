//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsView: View {
    var whisperState: WhisperState
    
    var body: some View {
        List {
            Section(header: Text("Local Whisper Models")) {
                ForEach(WhisperModel.models) { model in
                    
                    WhisperModelView(model: model) { model in
                        loadModel(whisperModel: model)
                    }
                    
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Models", displayMode: .inline)
    }
    
    
    func loadModel(whisperModel: WhisperModel) {
//        Task {
            // here
            whisperState.loadModel(modelUrl: whisperModel.fileURL)
//        }
    }
    
}

#Preview {
    @Previewable @State var whisperState = WhisperState()
    ModelsView(whisperState: whisperState)
}
