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
                NavigationLink("Cloud") {
                    CloudModelsList()
                }
                NavigationLink("Local") {
                    WhisperModelsList(appState: appState)
                }
            }
            .navigationBarTitle("Models")
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
