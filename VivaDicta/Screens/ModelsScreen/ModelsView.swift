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
        NavigationStack {
            List {
                NavigationLink(value: TranscriptionModel.cloud) {
                    Label("Cloud", systemImage: "cloud.circle")
                }
                NavigationLink(value: TranscriptionModel.local) {
                    Label("Local", systemImage: "cpu")
                }
            }
            .navigationBarTitle("Models")
            .navigationDestination(for: TranscriptionModel.self) { modelType in
                ModelsList(appState: appState, modelType: modelType)
            }
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
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsView(appState: appState)
}
