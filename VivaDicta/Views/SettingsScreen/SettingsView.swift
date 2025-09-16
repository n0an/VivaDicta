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
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Add New Mode button
                    NavigationLink(destination: ModeEditView(mode: nil, aiService: appState.aiService)) {
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
                    NavigationLink(destination: AIEnhancementSettings(appState: appState)) {
                        Text("AI Enhancement Settings")
                    }
                }
            }
            
            .navigationDestination(for: AIEnhanceMode.self) { mode in
                ModeEditView(mode: mode, aiService: appState.aiService)
            }
        }
    }
    
}


#Preview {
    @Previewable @State var appState = AppState()
    SettingsView(appState: appState)
}
