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
    @Environment(\.dismiss) private var dismiss
    
    @State private var modeName: String = ""
    @State private var transcriptionProvider: TranscriptionModelProvider = .local
    @State private var transcriptionModel: String = "base"
    @State private var aiEnhanceEnabled: Bool = false
    @State private var aiProvider: AIProvider = .openAI
    @State private var aiModel: String = "gpt-4o-mini"
    @State private var selectedPrompt: String = "Clean Transcript"
    
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
                    .pickerStyle(.menu)
                    
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
                    .pickerStyle(.menu)
//                    .foregroundColor(.secondary)
                }
                
                
                
                
                
                
                
                
                
                // Post-processing Section
                Section("AI Enhancement") {
                    HStack {
                        Text("Enabled")
                        Spacer()
                        Toggle("", isOn: $aiEnhanceEnabled)
                    }
                    
                    if aiEnhanceEnabled {
                        HStack {
                            Text("Provider")
                            Spacer()
                            Picker("AI Provider", selection: $aiProvider) {
                                Text("OpenAI").tag(AIProvider.openAI)
                                Text("Groq").tag(AIProvider.groq)
                                Text("Gemini").tag(AIProvider.gemini)
                                Text("OpenRouter").tag(AIProvider.openRouter)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Model")
                            Spacer()
                            Picker("AI Model", selection: $aiModel) {
                                Text("gpt-4o-mini").tag("gpt-4o-mini")
                                Text("gpt-4o").tag("gpt-4o")
                                Text("gpt-3.5-turbo").tag("gpt-3.5-turbo")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Prompt")
                            Spacer()
                            Picker("Prompt", selection: $selectedPrompt) {
                                Text("Clean Transcript").tag("Clean Transcript")
                                Text("Email Format").tag("Email Format")
                                Text("Note Format").tag("Note Format")
                                Text("Chat Format").tag("Chat Format")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.secondary)
                        }
                        
                        Text("Configure how the raw transcription should be processed and refined.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Mode" : "New Mode")
//            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMode()
                    }
                    .disabled(!isValid)
                }
            }
//        }
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
            aiProvider = existingMode.aiProvider ?? .openAI
            aiModel = existingMode.aiModel
            // TODO: Set selectedPrompt based on existingMode.prompt
        } else {
            modeName = ""
            transcriptionProvider = .local
            transcriptionModel = "base"
            aiEnhanceEnabled = false
            aiProvider = .openAI
            aiModel = "gpt-4o-mini"
            selectedPrompt = "Clean Transcript"
        }
    }
    
    private func saveMode() {
        let newMode = AIEnhanceMode(
            name: modeName.trimmingCharacters(in: .whitespacesAndNewlines),
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            prompt: getPromptForSelection(selectedPrompt),
            aiProvider: aiEnhanceEnabled ? aiProvider : nil,
            aiModel: aiModel,
            aiEnhanceEnabled: aiEnhanceEnabled
        )
        
        if isEditing {
            aiService.updateMode(newMode)
        } else {
            aiService.addMode(newMode)
        }
        
        dismiss()
    }
    
    private func getPromptForSelection(_ selection: String) -> String {
        // TODO: Return appropriate prompt based on selection
        return ""
    }
}

#Preview {
    @Previewable @State var aiService = AIService()
    ModeEditView(mode: nil, aiService: aiService)
}
