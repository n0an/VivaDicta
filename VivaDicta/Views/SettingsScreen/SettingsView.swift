//
//  SettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct SettingsView: View {
    
    @Bindable var appState: AppState
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Current Mode") {
                    Picker(selection: $appState.aiService.selectedMode) {
                        ForEach(AIEnhanceMode.predefinedModes) { mode in
                            Text(mode.name).tag(mode)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Active Mode")
                        }
                    }
                }
                
                Section("Configure Modes") {
                    
                    ForEach(AIEnhanceMode.predefinedModes) { mode in
                        NavigationLink(value: mode) {
                            Text(mode.name)
                                .font(.body)
                        }
                        
                    }
                }
            }
            .navigationDestination(for: AIEnhanceMode.self) { mode in
                AIModeConfigurationView(mode: mode, aiService: appState.aiService)
            }
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    SettingsView(appState: appState)
}
