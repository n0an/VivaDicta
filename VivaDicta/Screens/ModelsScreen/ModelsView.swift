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
                        CloudModelsList()
                    }
                    NavigationLink("Local") {
                        WhisperModelsList(appState: appState)
                    }
                }
            }
            .navigationBarTitle("Models", displayMode: .inline)
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    ModelsView(appState: appState)
}
