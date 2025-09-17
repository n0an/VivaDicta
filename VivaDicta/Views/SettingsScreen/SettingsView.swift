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
                // Modes section
                Section("Modes") {
                    
                    ForEach(appState.aiService.modes) { mode in
                        NavigationLink(value: mode) {
                            Text(mode.name)
                                .font(.body.weight(.medium))
                        }
                    }
                    
                    // Add New Mode button
                    NavigationLink(
                        destination: ModeEditView(
                            mode: nil,
                            aiService: appState.aiService,
                            promptsManager: appState.promptsManager,
                            appState: appState,
                            selectedTab: $appState.selectedTab)) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                .font(.title2)
                            
                            Text("Add New Mode")
                                .foregroundColor(.blue)
                                .font(.body)
                            
                            Spacer()
                            
                        }
                    }
                }
                
                Section("AI Enhancement") {
                    NavigationLink(destination: PromptsSettings(appState: appState)) {
                        Text("LLM Prompts")
                    }
                }
            }
            
            .navigationDestination(for: FlowMode.self) { mode in
                ModeEditView(
                    mode: mode,
                    aiService: appState.aiService,
                    promptsManager: appState.promptsManager,
                    appState: appState,
                    selectedTab: $appState.selectedTab)
            }
        }
    }
}


#Preview {
    @Previewable @State var appState = AppState()
    SettingsView(appState: appState)
}
