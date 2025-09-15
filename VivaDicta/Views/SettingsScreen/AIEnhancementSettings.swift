//
//  AIEnhancementSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct AIEnhancementSettings: View {
    @Bindable var appState: AppState
    
    var body: some View {
        Form {
            Section("Settings") {
                NavigationLink(destination: PromptsSettings(appState: appState)) {
                    Text("LLM Prompts")
                }
            }
        }
    }
}
