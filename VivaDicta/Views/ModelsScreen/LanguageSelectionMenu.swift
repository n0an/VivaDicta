//
//  LanguageSelectionMenu.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.05
//

import SwiftUI


//struct LanguageSelectionMenu: View {
//    var appState: AppState
//    
//    @AppStorage(Constants.kSelectedLanguageKey) private var selectedLanguage: String = "en"
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Transcription Language")
//                .font(.headline)
//
//            if let currentModel = appState.currentTranscriptionModel {
//                if languageSelectionDisabled {
//                    VStack(alignment: .leading, spacing: 8) {
//                        Text("Language: Autodetected")
//                            .font(.subheadline)
//                            .foregroundColor(.primary)
//
//                        Text("Current model: \(currentModel.displayName)")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//
//                        Text("The transcription language is automatically detected by the model.")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                } else if isMultilingualModel {
//                    VStack(alignment: .leading, spacing: 8) {
//                        Picker("Select Language", selection: $selectedLanguage) {
//                            ForEach(
//                                currentModel.supportedLanguages
//                                    .sorted(by: {
//                                    if $0.key == "auto" { return true }
//                                    return $0.value < $1.value
//                                }), id: \.key
//                            ) { key, value in
//                                Text(value).tag(key)
//                            }
//                        }
//                        .pickerStyle(.menu)
//                        .tint(.black)
//                        .background(.gray.opacity(0.2), in: .rect(cornerRadius: 8))
//                        .onChange(of: selectedLanguage) { _, newValue in
//                            updateLanguage(newValue)
//                        }
//
//                        Text("Current model: \(currentModel.displayName)")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//
//                        Text(
//                            "This model supports multiple languages. Select a specific language or auto-detect(if available)"
//                        )
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    }
//                } else {
//                    // For English-only models, force set language to English
//                    VStack(alignment: .leading, spacing: 8) {
//                        Text("Language: English")
//                            .font(.subheadline)
//                            .foregroundColor(.primary)
//
//                        Text("Current model: \(currentModel.displayName)")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//
//                        Text(
//                            "This is an English-optimized model and only supports English transcription."
//                        )
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    }
//                    .onAppear {
//                        // Force set English when viewing English-only model
//                        updateLanguage("en")
//                    }
//                }
//            } else {
//                Text("No model selected")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding()
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//    
//    private var languageSelectionDisabled: Bool {
//        guard let provider = appState.currentTranscriptionModel?.provider else {
//            return false
//        }
//        return provider == .parakeet || provider == .gemini
//    }
//    
//    private var isMultilingualModel: Bool {
//        guard let currentModel = appState.currentTranscriptionModel else {
//            return false
//        }
//        return currentModel.supportManyLanguages
//    }
//    
//    private func updateLanguage(_ language: String) {
//        // Force the prompt to update for the new language
//        appState.updateTranscriptionPrompt()
//    }
//}
