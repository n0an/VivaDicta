//
//  SettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct SettingsView: View {
    
    @Bindable var appState: AppState
    
    @State var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                            selectedTab: $appState.selectedTab,
                            navigationPath: $navigationPath)) {
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
                    NavigationLink(value: SettingsDestination.promptsSettings) {
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
                    selectedTab: $appState.selectedTab,
                    navigationPath: $navigationPath)
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .promptsSettings:
                    PromptsSettings(appState: appState)
                }
            }
            
        }
    }
}


#Preview {
    @Previewable @State var appState = AppState()
    SettingsView(appState: appState)
}
