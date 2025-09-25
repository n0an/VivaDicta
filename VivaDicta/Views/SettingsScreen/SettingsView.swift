//
//  SettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct SettingsView: View {

    @Bindable var appState: AppState
    @State var promptsManager = PromptsManager()

    @State var navigationPath = NavigationPath()
    @AppStorage("IsVADEnabled") private var isVADEnabled = true
    
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
                            promptsManager: promptsManager,
                            transcriptionManager: appState.transcriptionManager,
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
                
                Section("Transcription") {
                    Toggle(isOn: $isVADEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice Activity Detection")
                                .font(.body)
                            Text("Improves accuracy by detecting speech segments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    promptsManager: promptsManager,
                    transcriptionManager: appState.transcriptionManager,
                    selectedTab: $appState.selectedTab,
                    navigationPath: $navigationPath)
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .promptsSettings:
                    PromptsSettings(promptsManager: promptsManager)
                }
            }
            
        }
    }
}


#Preview {
    @Previewable @State var appState = AppState()
    SettingsView(appState: appState)
}


enum SettingsError: LocalizedError {
    case duplicateModeName(String)
    case unexpectedError(String)

    var errorDescription: String? {
        switch self {
        case .duplicateModeName(_):
            "Invalid Mode Name"
        case .unexpectedError(_):
            "Unexpected Error"
        }
    }

    var failureReason: String {
        switch self {
        case .duplicateModeName(let name):
            "There's already existing Mode with name \(name). Enter different name for this mode."
        case .unexpectedError(let message):
            "An unexpected error occurred: \(message). Please try again."
        }
    }
}
