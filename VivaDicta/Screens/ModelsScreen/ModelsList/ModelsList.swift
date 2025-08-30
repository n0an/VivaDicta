//
//  ModelsList.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.16
//

import SwiftUI

struct ModelsList: View {
    var appState: AppState
    var modelType: TranscriptionModel
    
    var body: some View {
        switch modelType {
        case .local:
            WhisperModelsList(appState: appState)
        case .cloud:
            CloudModelsList()
        }
        
        
        
    }
}

#Preview {
    @State @Previewable var appState = AppState()
    ModelsList(appState: appState,
               modelType: .cloud)
}
