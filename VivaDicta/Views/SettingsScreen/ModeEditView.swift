//
//  ModeEditView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct ModeEditView: View {
    let mode: AIEnhanceMode?
    let aiService: AIService
    let promptsManager: PromptsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: ModeEditViewModel
    @State private var modeName: String = ""
    @State private var transcriptionProvider: TranscriptionModelProvider = .local
    @State private var transcriptionModel: String = "base"
    @State private var aiEnhanceEnabled: Bool = false
    @State private var selectedPromptID: UUID?
    
    init(mode: AIEnhanceMode?, aiService: AIService, promptsManager: PromptsManager) {
        self.mode = mode
        self.aiService = aiService
        self.promptsManager = promptsManager
        self._viewModel = State(initialValue: ModeEditViewModel(aiService: aiService))
    }
    
    private var isEditing: Bool {
        mode != nil
    }
    
    private var isValid: Bool {
        !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        Form {
            Section("Mode Details") {
                TextField("Mode Name", text: $modeName)
            }
            
            Section("Transcription") {
                Picker("Provider", selection: $transcriptionProvider) {
                    ForEach(TranscriptionModelProvider.allCases) { provider in
                        Text(provider.rawValue.capitalized).tag(provider)
                    }
                }
                
                Picker("Model", selection: $transcriptionModel) {
                    if transcriptionProvider == .local {
                        Text("base").tag("base")
                        Text("small").tag("small")
                        Text("medium").tag("medium")
                        Text("large").tag("large")
                    } else {
                        Text(transcriptionModel).tag(transcriptionModel)
                    }
                }
            }
            
            Section(header: Text("AI Enhancement"),
                    footer: aiEnhanceEnabled ? Text("Configure how the raw transcription should be processed and refined.") : nil) {
                
                Toggle("Enable", isOn: $aiEnhanceEnabled)
                
                if aiEnhanceEnabled {
                    Picker(selection: $viewModel.aiProvider) {
                        Text("None").tag(nil as AIProvider?)
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue.capitalized).tag(provider as AIProvider?)
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
                    
                    Picker("Prompt", selection: $selectedPromptID) {
                        ForEach(promptsManager.userPrompts) { prompt in
                            Text(prompt.title).tag(prompt.id)
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Mode" : "New Mode")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveMode()
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            loadModeData()
        }
    }
    
    private func loadModeData() {
        if let existingMode = mode {
            modeName = existingMode.name
            transcriptionProvider = existingMode.transcriptionProvider
            transcriptionModel = existingMode.transcriptionModel
            aiEnhanceEnabled = existingMode.aiEnhanceEnabled
            viewModel.loadFromMode(existingMode)
            
            // Find prompt by matching prompt text
            if !existingMode.prompt.isEmpty {
                selectedPromptID = promptsManager.userPrompts.first { prompt in
                    prompt.promptInstructions == existingMode.prompt
                }?.id
            } else {
                selectedPromptID = nil
            }
        } else {
            modeName = ""
            transcriptionProvider = .local
            transcriptionModel = "base"
            aiEnhanceEnabled = false
            viewModel.updateProvider(.openAI)
            selectedPromptID = nil
        }
    }
    
    private func saveMode() {
        let newMode = AIEnhanceMode(
            name: modeName.trimmingCharacters(in: .whitespacesAndNewlines),
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            prompt: getPromptForSelection(selectedPromptID),
            aiProvider: aiEnhanceEnabled ? viewModel.getCurrentProvider() : nil,
            aiModel: viewModel.getCurrentModel(),
            aiEnhanceEnabled: aiEnhanceEnabled
        )
        
        if isEditing {
            aiService.updateMode(newMode)
        } else {
            aiService.addMode(newMode)
        }
        
        dismiss()
    }
    
    private func getPromptForSelection(_ promptID: UUID?) -> String {
        guard let promptID = promptID,
              let selectedPrompt = promptsManager.userPrompts.first(where: { $0.id == promptID }) else {
            return ""
        }
        return selectedPrompt.promptInstructions
    }
}

#Preview {
    @Previewable @State var aiService = AIService()
    @Previewable @State var promptsManager = PromptsManager()
    ModeEditView(mode: nil, aiService: aiService, promptsManager: promptsManager)
}
