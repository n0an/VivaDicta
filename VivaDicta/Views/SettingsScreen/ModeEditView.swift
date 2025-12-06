//
//  ModeEditView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI
import TipKit

struct ModeEditView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var navigationPath: NavigationPath
    
    @State private var viewModel: ModeEditViewModel
    
    @State private var showingAlert: Bool = false
    @State private var modeEditViewError: SettingsError = .duplicateModeName("")
    
    let selectAIEnhacementTip = SelectAIEnhacementTip()
    
    init(mode: FlowMode?,
         aiService: AIService,
         promptsManager: PromptsManager,
         transcriptionManager: TranscriptionManager,
         navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
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
            
            Section(header: Text("Transcription"),
                    footer: Text(viewModel.transcriptionFooterText)) {
                
                Picker("Provider", selection: $viewModel.transcriptionProvider) {
                    ForEach(TranscriptionModelProvider.allCases) { provider in
                        Text(provider.rawValue.capitalized).tag(provider)
                    }
                }
//                .tint(.primary)
//                .pickerStyle(.menu)
                .onChange(of: viewModel.transcriptionProvider) { _, newProvider in
                    viewModel.updateTranscriptionProvider(newProvider)
                }
                
                if viewModel.isTranscriptionProviderConfigured(viewModel.transcriptionProvider) {
                    Picker("Model", selection: $viewModel.transcriptionModel) {
                        ForEach(viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider), id: \.self) { model in
                            Text(viewModel.transcriptionProvider.getTranscriptionModelDisplayName(model))
                                .tag(model)
                        }
                    }
                    .onChange(of: viewModel.transcriptionModel) { _, newModel in
                        viewModel.updateTranscriptionModel(newModel)
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
                    if viewModel.transcriptionProvider == .parakeet ||
                        viewModel.transcriptionProvider == .whisperKit {
                        Button {
                            navigationPath.append(SettingsDestination.transcriptionModels)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Download Local Transcription Model")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.blue)
                    } else {
                        if let mappedProvider = viewModel.transcriptionProvider.mappedAIProvider {
                            
                            
                            NavigationLink {
                                AddAPIKeyView(
                                    provider: mappedProvider,
                                    aiService: viewModel.aiService,
                                    onSave: { _ in
                                        let availableModels = viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider)
                                        if let firstModel = availableModels.first {
                                            viewModel.transcriptionModel = firstModel
                                        }
                                    })
                            } label: {
                                HStack {
                                    Image(systemName: "key")
                                    Text("Add API Key")
                                }
                            }

                            
                            
//                            NavigationLink(destination: AddAPIKeyView(
//                                provider: mappedProvider,
//                                aiService: viewModel.aiService,
//                                onSave: { _ in
//                                    let availableModels = viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider)
//                                    if let firstModel = availableModels.first {
//                                        viewModel.transcriptionModel = firstModel
//                                    }
//                                })) {
//                                    HStack {
//                                        Image(systemName: "key")
//                                        Text("Add API Key")
//                                    }
//                                }
                        }
                    }
                }
            }
            
            if viewModel.isTranscriptionProviderConfigured(viewModel.transcriptionProvider) {
                
                Section(header: Text("AI Enhancement"),
                        footer: Text("Configure how the raw transcription should be processed and refined.")) {
                    
                    TipView(selectAIEnhacementTip)
                        .tipBackground(.teal.gradient)
                    
                    Toggle("Enable", isOn: $viewModel.aiEnhanceEnabled)
                    
                    if viewModel.aiEnhanceEnabled {
                        Picker(selection: $viewModel.aiProvider) {
                            ForEach(AIProvider.generalProviders) { provider in
                                Text(provider.rawValue.capitalized).tag(provider)
                            }
                            
                        } label: {
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundStyle(Gradient(colors: [.purple, .red, .blue]))
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
                                    ForEach(viewModel.aiService.getAvailableModels(for: provider), id: \.self) { model in
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
                                
                                
                                NavigationLink {
                                    AddAPIKeyView(
                                        provider: provider,
                                        aiService: viewModel.aiService, onSave: { provider in
                                            viewModel.updateModel(provider.defaultModel)
                                        })
                                } label: {
                                    HStack {
                                        Image(systemName: "key")
                                        Text("Add API Key")
                                    }
                                }

                                
//                                NavigationLink(destination: AddAPIKeyView(
//                                    provider: provider,
//                                    aiService: viewModel.aiService, onSave: { provider in
//                                        viewModel.updateModel(provider.defaultModel)
//                                    })) {
//                                        HStack {
//                                            Image(systemName: "key")
//                                            Text("Add API Key")
//                                        }
//                                    }
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
        .onChange(of: viewModel.aiEnhanceEnabled, { oldValue, newValue in
            if newValue == true {
                selectAIEnhacementTip.invalidate(reason: .actionPerformed)
            }
        })
        .alert(isPresented: $showingAlert,
               error: modeEditViewError,
               actions: { error in
            // Actions
        }, message: { error in
            Text(error.failureReason)
        })
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
        
        do {
            let newMode = try viewModel.saveMode()
            if viewModel.isEditing {
                viewModel.aiService.updateMode(newMode)
            } else {
                viewModel.aiService.addMode(newMode)
            }
            dismiss()
        } catch SettingsError.duplicateModeName(let name) {
            showingAlert = true
            modeEditViewError = .duplicateModeName(name)
        } catch {
            showingAlert = true
            modeEditViewError = .unexpectedError(error.localizedDescription)
        }
        
    }
}

#Preview {
    @Previewable @State var aiService = AIService()
    @Previewable @State var promptsManager = PromptsManager()
    @Previewable @State var appState = AppState()
    @Previewable @State var transcriptionManager = TranscriptionManager()
    @Previewable @State var navigationPath = NavigationPath()
    ModeEditView(
        mode: nil,
        aiService: aiService,
        promptsManager: promptsManager,
        transcriptionManager: transcriptionManager,
        navigationPath: $navigationPath)
}
