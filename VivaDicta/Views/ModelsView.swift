//
//  ModelsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import SwiftUI

struct ModelsView: View {
//    @ObservedObject var whisperState: WhisperState
    @Environment(\.dismiss) var dismiss
    

    func loadModel(WhisperModel: WhisperModel) {
        Task {
            dismiss()
//            whisperState.loadModel(path: WhisperModel.fileURL)
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
