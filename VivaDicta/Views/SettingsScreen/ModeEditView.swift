//
//  ModeEditView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct ModeEditView: View {
    let aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: TabTag

    @State private var viewModel: ModeEditViewModel

    init(mode: FlowMode?,
         aiService: AIService,
         promptsManager: PromptsManager,
         appState: AppState,
         selectedTab: Binding<TabTag>) {
        self.aiService = aiService
        self._selectedTab = selectedTab

        self._viewModel = State(
            initialValue: ModeEditViewModel(
                mode: mode,
                aiService: aiService,
                promptsManager: promptsManager,
                appState: appState))
    }
    
    var body: some View {
        Form {
            Section("Mode Details") {
                TextField("Mode Name", text: $viewModel.modeName)
            }
            
            Section("Transcription") {
                if viewModel.hasAvailableTranscriptionProviders() {
                    Picker("Provider", selection: $viewModel.transcriptionProvider) {
                        ForEach(viewModel.getAvailableProviders()) { provider in
                            Text(provider.rawValue.capitalized).tag(provider)
                        }
                    }
                    .onChange(of: viewModel.transcriptionProvider) { _, newProvider in
                        viewModel.updateTranscriptionProvider(newProvider)
                    }
                    .onAppear {
                        viewModel.validateAndAutoSelectProvider()
                    }

                    Picker("Model", selection: $viewModel.transcriptionModel) {
                        ForEach(viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider), id: \.self) { model in
                            Text(viewModel.getTranscriptionModelDisplayName(model, provider: viewModel.transcriptionProvider))
                                .tag(model)
                        }
                    }
                } else {
                    Button {
                        dismiss()
                        selectedTab = .models
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Select Model")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("AI Enhancement"),
                    footer: viewModel.aiEnhanceEnabled ? Text("Configure how the raw transcription should be processed and refined.") : nil) {
                
                Toggle("Enable", isOn: $viewModel.aiEnhanceEnabled)
                
                if viewModel.aiEnhanceEnabled {
                    Picker(selection: $viewModel.aiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue.capitalized).tag(provider)
                        }
                        
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                            Text("AI Provider")
                        }
                    }
                    .onChange(of: viewModel.aiProvider) { _, newProvider in
                        viewModel.updateProvider(newProvider)
                    }
                    
                    if let provider = viewModel.aiProvider {
                        let hasKey = viewModel.hasAPIKey(for: provider)
                        if hasKey {
                            
                            Picker(selection: $viewModel.aiModel) {
                                ForEach(aiService.getAvailableModels(for: provider), id: \.self) { model in
                                    Text(model).tag(model as String?)
                                }
                                
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("AI Model")
                                }
                            }
                            .onChange(of: viewModel.aiModel) { _, newModel in
                                viewModel.updateModel(newModel)
                            }
                            
                        } else {
                            NavigationLink(destination: AddAPIKeyView(
                                provider: provider,
                                aiService: aiService, onSave: { provider in
                                    viewModel.updateModel(provider.defaultModel)
                                })) {
                                    HStack {
                                        Image(systemName: "key")
                                        Text("Add API Key")
                                    }
                                }
                        }
                    }
                    
                    Picker("Prompt", selection: $viewModel.selectedPromptID) {
                        ForEach(viewModel.promptsManager.userPrompts) { prompt in
                            Text(prompt.title).tag(prompt.id)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit Mode" : "New Mode")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveMode()
                }
                .disabled(!viewModel.isValid)
            }
        }
    }
    
    private func saveMode() {
        let newMode = viewModel.saveMode()
        if viewModel.isEditing {
            aiService.updateMode(newMode)
        } else {
            aiService.addMode(newMode)
        }
        dismiss()
    }
}

#Preview {
    @Previewable @State var aiService = AIService()
    @Previewable @State var promptsManager = PromptsManager()
    @Previewable @State var appState = AppState()
    @Previewable @State var selectedTab: TabTag = .settings
    ModeEditView(
        mode: nil,
        aiService: aiService,
        promptsManager: promptsManager,
        appState: appState,
        selectedTab: $selectedTab)
}
