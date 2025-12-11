//
//  SettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI
import AppIntents
import TipKit

struct SettingsView: View {

    var appState: AppState
    @State var promptsManager = PromptsManager()

    @Environment(\.dismiss) private var dismiss
    @State var navigationPath = NavigationPath()
//    @Namespace private var promptsTransition
    @AppStorage(AppGroupCoordinator.kIsVADEnabled, store: UserDefaultsStorage.shared)
    private var isVADEnabled = true
    @AppStorage(UserDefaultsStorage.Keys.isTextFormattingEnabled)
    private var isTextFormattingEnabled = true
    @AppStorage(UserDefaultsStorage.Keys.audioSessionTimeout)
    private var audioSessionTimeout = 180
    private let prewarmManager = AudioPrewarmManager.shared
    @State private var showPrewarmError = false
    @State private var prewarmErrorMessage = ""
    
    @AppStorage(UserDefaultsStorage.Keys.displaySiriTip) private var displaySiriTip: Bool = true
    @State private var isSmartFormattingEnabled = AppGroupCoordinator.shared.isSmartFormattingOnPasteEnabled
    @State private var isKeepInClipboardEnabled = AppGroupCoordinator.shared.isKeepTranscriptInClipboardEnabled
    @State private var isHapticFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled
    @State private var isSoundFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled

    let selectTranscriptionModelTipSettingsView = SelectTranscriptionModelTipSettingsView()
    
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if appState.aiService.modes.count > 1 {
                                Button(role: .destructive) {
                                    deleteMode(mode)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    // Add New Mode button - only show if models are available
                    if appState.transcriptionManager.hasAvailableTranscriptionModels {
                        NavigationLink(
                            destination: ModeEditView(
                                mode: nil,
                                aiService: appState.aiService,
                                promptsManager: promptsManager,
                                transcriptionManager: appState.transcriptionManager,
                                navigationPath: $navigationPath)) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.title2)
                                         
                                        Text("Add New Mode")
                                            .foregroundStyle(.blue)
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                    }
                                }
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("Download models or configure API keys to add new modes")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                }
                
                Section("Transcription") {
//                    TipView(selectTranscriptionModelTipSettingsView)
                    
                    NavigationLink(value: SettingsDestination.transcriptionModels) {
                        Text("Transcription Models")
                    }
                    .popoverTip(selectTranscriptionModelTipSettingsView)

                    Toggle(isOn: $isVADEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice Activity Detection")
                                .font(.body)
                            Text("Improves accuracy by detecting speech segments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $isTextFormattingEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Automatic Text Formatting")
                                .font(.body)
                            Text("Splits transcription into readable paragraphs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Dictionary") {
                    NavigationLink(value: SettingsDestination.correctSpelling) {
                        Text("Spelling Corrections")
                    }

                    NavigationLink(value: SettingsDestination.replacements) {
                        Text("Word Replacements")
                    }
                }
                
                Section("AI Enhancement") {
                    NavigationLink(value: SettingsDestination.promptsSettings) {
                        Text("LLM Prompts")
                    }
                }

                Section("Keyboard") {
                    Button(action: activateKeyboardRecordingSession) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.blue)
                                .font(.body)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Keyboard Recording Session")
                                    .foregroundStyle(.blue)
                                    .font(.body)

                                if prewarmManager.isSessionActiveObservable {
                                    HStack {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 6)

                                        Text("Session active")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }

                                }
                            }

                            Spacer()
                        }
                    }
                    .disabled(prewarmManager.isSessionActiveObservable)
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Session Timeout", selection: $audioSessionTimeout) {
                            Text("Immediate").tag(0)
                            Text("15 seconds").tag(15)
                            Text("30 seconds").tag(30)
                            Text("60 seconds").tag(60)
                            Text("90 seconds").tag(90)
                            Text("2 minutes").tag(120)
                            Text("3 minutes").tag(180)
                            Text("5 minutes").tag(300)
                            Text("15 minutes").tag(900)
                            Text("30 minutes").tag(1800)
                            Text("1 hour").tag(3600)
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)

                        Text("Keep microphone session active to allow recording from keyboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: $isSmartFormattingEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smart Insert")
                                .font(.body)
                            Text("Auto-adjust spacing and capitalization when inserting text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isSmartFormattingEnabled) { _, newValue in
                        AppGroupCoordinator.shared.isSmartFormattingOnPasteEnabled = newValue
                    }

                    Toggle(isOn: $isKeepInClipboardEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Copy to Clipboard")
                                .font(.body)
                            Text("Keep transcript in clipboard after inserting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isKeepInClipboardEnabled) { _, newValue in
                        AppGroupCoordinator.shared.isKeepTranscriptInClipboardEnabled = newValue
                    }

                    Toggle(isOn: $isHapticFeedbackEnabled) {
                        Text("Haptic Feedback")
                            .font(.body)
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Haptic Feedback")
//                                .font(.body)
//                            Text("Vibrate on key press")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                        }
                    }
                    .onChange(of: isHapticFeedbackEnabled) { _, newValue in
                        AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled = newValue
                    }
                    
                    Toggle(isOn: $isSoundFeedbackEnabled) {
                        Text("Sound")
                            .font(.body)
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Haptic Feedback")
//                                .font(.body)
//                            Text("Vibrate on key press")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                        }
                    }
                    .onChange(of: isSoundFeedbackEnabled) { _, newValue in
                        AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled = newValue
                    }
                }
                
//                ShortcutsLink()
            }
            .navigationDestination(for: FlowMode.self) { mode in
                ModeEditView(
                    mode: mode,
                    aiService: appState.aiService,
                    promptsManager: promptsManager,
                    transcriptionManager: appState.transcriptionManager,
                    navigationPath: $navigationPath)
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .promptsSettings:
                    PromptsSettings(promptsManager: promptsManager)
                case .transcriptionModels:
                    ModelsView(appState: appState)
                case .promptsTemplates:
                    TemplateSelectionView(promptsManager: promptsManager)
//                        .navigationTransition(.zoom(sourceID: "addPrompt", in: promptsTransition))
                case .correctSpelling:
                    WordsDictionaryView()
                case .replacements:
                    ReplacementsView()
                }
            }
            .navigationDestination(for: UserPrompt.self) { prompt in
                PromptEditView(
                    editingPrompt: prompt,
                    promptsManager: promptsManager
                )
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }

        }
        .onAppear {
            if appState.shouldNavigateToModels {
                appState.shouldNavigateToModels = false
                navigationPath.append(SettingsDestination.transcriptionModels)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SiriTipView(intent: ToggleRecordIntent(), isVisible: $displaySiriTip)
            .padding(.horizontal)
//            .background(.ultraThinMaterial)
        }
        
        .alert("Prewarm Session Error", isPresented: $showPrewarmError) {
            Button("OK") {
                showPrewarmError = false
            }
        } message: {
            Text(prewarmErrorMessage)
        }
    }
    
    private func deleteMode(_ mode: FlowMode) {
        // Prevent deletion if there's only one mode
        guard appState.aiService.modes.count > 1 else { return }

        appState.aiService.deleteMode(mode)
    }

    // MARK: - Keyboard Recording Session Actions

    private func activateKeyboardRecordingSession() {
        Task {
            do {
                // Start the pre-warm session (same as when receiving deep link)
                try await prewarmManager.startPrewarmSession()

                // Activate keyboard session to notify keyboard that hot mic is ready
                AppGroupCoordinator.shared.activateKeyboardSession(
                    timeoutSeconds: prewarmManager.audioSessionTimeout
                )

            } catch {
                prewarmErrorMessage = "Failed to activate session: \(error.localizedDescription)"
                showPrewarmError = true
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
