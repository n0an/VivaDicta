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
    
    let selectLanguageTip = SelectLanguageTip()

    
    init(mode: VivaMode?,
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
                    footer: transcriptionSectionFooter) {
                
                Picker("Provider", selection: $viewModel.transcriptionProvider) {
                    Section("On-Device") {
                        ForEach(TranscriptionModelProvider.localProviders) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    Section("Cloud") {
                        ForEach(TranscriptionModelProvider.cloudProviders) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }
//                .tint(.primary)
//                .pickerStyle(.menu)
                .onChange(of: viewModel.transcriptionProvider) { _, newProvider in
                    HapticManager.selectionChanged()
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
                        HapticManager.selectionChanged()
                    }
                    .onAppear {
                        let availableModels = viewModel.getAvailableTranscriptionModels(for: viewModel.transcriptionProvider)
                        if !availableModels.contains(viewModel.transcriptionModel) && !availableModels.isEmpty {
                            viewModel.transcriptionModel = availableModels.first ?? ""
                        }
                    }
                    
                    if viewModel.isLanguageSelectionAvailable() {
                        let grouped = viewModel.getGroupedLanguages()
                        Picker("Language", selection: $viewModel.transcriptionLanguage) {
                            ForEach(grouped.recommended, id: \.key) { key, value in
                                Text(TranscriptionModelProvider.languageWithFlag(key, name: value)).tag(key)
                            }

                            if !grouped.recommended.isEmpty && !grouped.other.isEmpty {
                                Divider()
                            }

                            ForEach(grouped.other, id: \.key) { key, value in
                                Text(TranscriptionModelProvider.languageWithFlag(key, name: value)).tag(key)
                            }
                        }
                        .onChange(of: viewModel.transcriptionLanguage) { _, _ in
                            HapticManager.selectionChanged()
                        }
                        .popoverTip(selectLanguageTip)

                    } else { // Auto-detected language models - Gemini and Parakeet
                        HStack {
                            Text("Language")
                            Spacer()
                            Text("Autodetected by model")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    if viewModel.transcriptionProvider == .parakeet ||
                        viewModel.transcriptionProvider == .whisperKit {
                        Button {
                            navigationPath.append(SettingsDestination.transcriptionModels)
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Download Model")
                                Spacer()
                                Text("Required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
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
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Add API Key")
                                    Spacer()
                                    Text("Required")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            if viewModel.isTranscriptionProviderConfigured(viewModel.transcriptionProvider) {

                Section(header: Text("AI Enhancement"),
                        footer: aiEnhancementSectionFooter) {

                    if !viewModel.aiEnhanceEnabled {
                        TipView(selectAIEnhacementTip)
                            .tipBackground(.teal.gradient)
                    }

                    Toggle("Enable", isOn: $viewModel.aiEnhanceEnabled)

                    if viewModel.aiEnhanceEnabled {
                        Picker(selection: $viewModel.aiProvider) {
                            // Show Apple at top if available (on-device section)
                            if viewModel.isAppleFoundationModelAvailable {
                                Section("On-Device") {
                                    Label("Apple", systemImage: "apple.intelligence")
                                        .tag(AIProvider.apple)
                                }
                            }
                            // Cloud providers section
                            Section("Cloud") {
                                ForEach(AIProvider.cloudProviders) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
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
                            HapticManager.selectionChanged()
                        }
                        .onAppear {
                            viewModel.selectFirstProviderIfNeeded()
                        }

                        if let provider = viewModel.aiProvider {
                            let isReady = viewModel.isProviderReady(provider)
                            if isReady {
                                // Show model picker for Apple with just "Foundation Model"
                                if provider == .apple {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("AI Model")
                                        Spacer()
                                        Text("Foundation Model")
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
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
                                        HapticManager.selectionChanged()
                                    }
                                }
                            } else {
                                // Apple provider not available - show status message
                                if provider == .apple {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text(viewModel.appleFoundationModelStatusMessage)
                                            .font(.callout)
                                    }
                                } else {
                                    // Cloud provider needs API key
                                    NavigationLink {
                                        AddAPIKeyView(
                                            provider: provider,
                                            aiService: viewModel.aiService, onSave: { provider in
                                                viewModel.updateModel(provider.defaultModel)
                                            })
                                    } label: {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.orange)
                                            Text("Add API Key")
                                            Spacer()
                                            Text("Required")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        if let provider = viewModel.aiProvider, viewModel.isProviderReady(provider) {
                            if viewModel.promptsManager.userPrompts.isEmpty {
                                Button(action: {
                                    navigationPath.append(SettingsDestination.promptsSettings)
                                }) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text("Add Prompt")
                                        Spacer()
                                        Text("Required")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(.primary)
                            } else {
                                Picker("Prompt", selection: $viewModel.selectedPromptID) {
                                    ForEach(viewModel.promptsManager.userPrompts) { prompt in
                                        Text(prompt.title).tag(prompt.id)
                                    }
                                }
                                .onChange(of: viewModel.selectedPromptID) { _, _ in
                                    HapticManager.selectionChanged()
                                }
                                .onAppear {
                                    viewModel.selectFirstPromptIfNeeded()
                                }
                            }
                        }
                    }
                }
            }

            if viewModel.isEditing {
                Section {
                    
                    Button {
                        duplicateMode()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Duplicate Mode", systemImage: "doc.on.doc")
                            Spacer()
                        }
                    }
                }
                
                if viewModel.aiService.modes.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            deleteMode()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Mode", systemImage: "trash")
                                    .foregroundStyle(.red)
                                Spacer()
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
        .onChange(of: viewModel.transcriptionLanguage, { oldValue, newValue in
            selectLanguageTip.invalidate(reason: .actionPerformed)
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
                if #available(iOS 26, *) {
                    Button(role: .confirm) {
                        saveMode()
                    }
                    .disabled(!viewModel.isValid)
                    .tint(.blue)
                } else {
                    Button("Save") {
                        saveMode()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
    @ViewBuilder
    private var transcriptionSectionFooter: some View {
        if let validationMessage = viewModel.transcriptionValidationMessage {
            Label(validationMessage, systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.caption)
                .accessibilityLabel("Required: \(validationMessage)")
        } else if !viewModel.transcriptionFooterText.isEmpty {
            Text(viewModel.transcriptionFooterText)
        }
    }

    @ViewBuilder
    private var aiEnhancementSectionFooter: some View {
        if let validationMessage = viewModel.aiEnhancementValidationMessage {
            Label(validationMessage, systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.caption)
                .accessibilityLabel("Required: \(validationMessage)")
        } else {
            Text("Configure how the raw transcription should be processed and refined.")
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
            HapticManager.error()
            showingAlert = true
            modeEditViewError = .duplicateModeName(name)
        } catch {
            HapticManager.error()
            showingAlert = true
            modeEditViewError = .unexpectedError(error.localizedDescription)
        }

    }

    private func duplicateMode() {
        guard let mode = viewModel.originalMode else { return }
        HapticManager.heavyImpact()
        viewModel.aiService.duplicateMode(mode)
        dismiss()
    }

    private func deleteMode() {
        guard let mode = viewModel.originalMode,
              viewModel.aiService.modes.count > 1 else { return }
        HapticManager.heavyImpact()
        viewModel.aiService.deleteMode(mode)
        dismiss()
    }
}

#Preview {
    @Previewable @State var aiService = AIService()
    @Previewable @State var promptsManager = PromptsManager()
//    @Previewable @State var appState = AppState(modelContainer: TranscriptionsMockData.makeSharedContext())
    @Previewable @State var transcriptionManager = TranscriptionManager()
    @Previewable @State var navigationPath = NavigationPath()
    ModeEditView(
        mode: nil,
        aiService: aiService,
        promptsManager: promptsManager,
        transcriptionManager: transcriptionManager,
        navigationPath: $navigationPath)
}
