//
//  LanguageSelectionMenu.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.05
//

import SwiftUI


struct LanguageSelectionMenu: View {
    
    var appState: AppState
    
    @State var selectedLanguagePicker = "Auto"
    
    @AppStorage(kSelectedLanguageKey) private var selectedLanguage: String = "en"
    
    var body: some View {
        Menu("Language", systemImage: "globe") {
            Picker("Language", selection: $selectedLanguagePicker) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transcription Language")
                        .font(.headline)

                    if let currentModel = appState.currentTranscriptionModel {
                        if languageSelectionDisabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Language: Autodetected")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Text("Current model: \(currentModel.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("The transcription language is automatically detected by the model.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .disabled(true)
                        } else if isMultilingualModel {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Select Language", selection: $selectedLanguage) {
                                    ForEach(
                                        currentModel.supportedLanguages.sorted(by: {
                                            if $0.key == "auto" { return true }
                                            if $1.key == "auto" { return false }
                                            return $0.value < $1.value
                                        }), id: \.key
                                    ) { key, value in
                                        Text(value).tag(key)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: selectedLanguage) { oldValue, newValue in
                                    updateLanguage(newValue)
                                }

                                Text("Current model: \(currentModel.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(
                                    "This model supports multiple languages. Select a specific language or auto-detect(if available)"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        } else {
                            // For English-only models, force set language to English
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Language: English")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Text("Current model: \(currentModel.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(
                                    "This is an English-optimized model and only supports English transcription."
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .onAppear {
                                // Ensure English is set when viewing English-only model
                                updateLanguage("en")
                            }
                        }
                    } else {
                        Text("No model selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.gray)
                .cornerRadius(10)
            }
        }
    }
    
    private var languageSelectionDisabled: Bool {
        guard let provider = appState.currentTranscriptionModel?.provider else {
            return false
        }
        return provider == .parakeet || provider == .gemini
    }
    
    private var isMultilingualModel: Bool {
        guard let currentModel = appState.currentTranscriptionModel else {
            return false
        }
        return currentModel.supportManyLanguages
    }
    
    private func updateLanguage(_ language: String) {
        selectedLanguage = language
        
        // Force the prompt to update for the new language
        appState.updateTranscriptionPrompt()

//        // Post notification for language change
//        NotificationCenter.default.post(name: .languageDidChange, object: nil)
//        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
}
