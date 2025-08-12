//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsView: View {
    var whisperState: WhisperState
    
    func loadModel(whisperModel: WhisperModel) {
        Task {
            whisperState.loadModel(modelUrl: whisperModel.fileURL)
        }
    }
    
    var body: some View {
        List {
            Section(header: Text("Models")) {
                ForEach(WhisperModel.models) { WhisperModel in
                    DownloadButton(model: WhisperModel)
                        .onLoad(perform: loadModel)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Models", displayMode: .inline).toolbar {}
    }
}

#Preview {
    @Previewable @State var whisperState = WhisperState()
    ModelsView(whisperState: whisperState)
}
