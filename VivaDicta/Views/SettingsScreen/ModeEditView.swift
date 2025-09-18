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
    
    @Binding var navigationPath: NavigationPath
    
    @State private var viewModel: ModeEditViewModel
    
    init(mode: FlowMode?,
         aiService: AIService,
         promptsManager: PromptsManager,
         transcriptionManager: TranscriptionManager,
         selectedTab: Binding<TabTag>,
         navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.aiService = aiService
        self._selectedTab = selectedTab
        self._navigationPath = navigationPath
        
        self._viewModel = State(
            initialValue: ModeEditViewModel(
                mode: mode,
                aiService: aiService,
                promptsManager: promptsManager,
                transcriptionManager: transcriptionManager))
    }
    
    var body: some View {
        Form {
            Section("Mode Details") {
                TextField("Mode Name", text: $viewModel.modeName)
            }
            
            Section("Transcription") {
                Picker("Provider", selection: $viewModel.transcriptionProvider) {
                    ForEach(TranscriptionModelProvider.allCases) { provider in
                        Text(provider.rawValue.capitalized).tag(provider)
                    }
                }
                .onChange(of: viewModel.transcriptionProvider) { _, newProvider in
                    viewModel.updateTranscriptionProvider(newProvider)
                }
                
                if viewModel.isTranscriptionProviderConfigured(viewModel.transcriptionProvider) {
                    Picker("Model", selection: $viewModel.transcriptionModel) {
                        ForEach(viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider), id: \.self) { model in
                            Text(viewModel.getTranscriptionModelDisplayName(model, provider: viewModel.transcriptionProvider))
                                .tag(model)
                        }
                    }
                    .onAppear {
                        let availableModels = viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider)
                        if !availableModels.contains(viewModel.transcriptionModel) && !availableModels.isEmpty {
                            viewModel.transcriptionModel = availableModels.first ?? ""
                        }
                    }
                    
                    if viewModel.isLanguageSelectionAvailable() {
                        Picker("Language", selection: $viewModel.transcriptionLanguage) {
                            ForEach(Array(viewModel.getAvailableLanguages()), id: \.key) { key, value in
                                Text(value).tag(key)
                            }
                        }
                    }
                } else {
                    if viewModel.transcriptionProvider == .local {
                        Button {
                            dismiss()
                            selectedTab = .models
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Download Local Model")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.blue)
                    } else {
                        if let mappedProvider = viewModel.transcriptionProvider.mappedAIProvider {
                            NavigationLink(destination: AddAPIKeyView(
                                provider: mappedProvider,
                                aiService: aiService,
                                onSave: { _ in
                                    let availableModels = viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider)
                                    if let firstModel = availableModels.first {
                                        viewModel.transcriptionModel = firstModel
                                    }
                                })) {
                                    HStack {
                                        Image(systemName: "key")
                                        Text("Add API Key")
                                    }
                                }
                        }
                    }
                }
            }
            
            if viewModel.isTranscriptionProviderConfigured(viewModel.transcriptionProvider) {
                Section(header: Text("AI Enhancement"),
                        footer: Text("Configure how the raw transcription should be processed and refined.")) {
                    
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
                        
                        if let provider = viewModel.aiProvider, viewModel.hasAPIKey(for: provider) {
                            if viewModel.promptsManager.userPrompts.isEmpty {
                                Button(action: {
                                    navigationPath.append(SettingsDestination.promptsSettings)
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("Add Prompt")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Picker("Prompt", selection: $viewModel.selectedPromptID) {
                                    ForEach(viewModel.promptsManager.userPrompts) { prompt in
                                        Text(prompt.title).tag(prompt.id)
                                    }
                                }
                            }
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
    @Previewable @State var aiService = AIService(transcriptionManager: TranscriptionManager())
    @Previewable @State var promptsManager = PromptsManager()
    @Previewable @State var appState = AppState()
    @Previewable @State var transcriptionManager = TranscriptionManager()
    @Previewable @State var selectedTab: TabTag = .settings
    @Previewable @State var navigationPath = NavigationPath()
    ModeEditView(
        mode: nil,
        aiService: aiService,
        promptsManager: promptsManager,
        transcriptionManager: transcriptionManager,
        selectedTab: $selectedTab,
        navigationPath: $navigationPath)
}
