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
    @Environment(AppState.self) var appState

    @State var promptsManager = PromptsManager()

    @Environment(\.dismiss) private var dismiss
    @State var navigationPath = NavigationPath()
//    @Namespace private var promptsTransition
    @AppStorage(AppGroupCoordinator.kIsVADEnabled, store: UserDefaultsStorage.shared)
    private var isVADEnabled = true
    @AppStorage(UserDefaultsStorage.Keys.isTextFormattingEnabled)
    private var isTextFormattingEnabled = true
    @AppStorage(UserDefaultsStorage.Keys.audioSessionTimeout)
    private var audioSessionTimeout: Int = 180
    private let prewarmManager = AudioPrewarmManager.shared
    @State private var showPrewarmError = false
    @State private var prewarmErrorMessage = ""
    
    @AppStorage(UserDefaultsStorage.Keys.displaySiriTip) private var displaySiriTip: Bool = true
    @State private var isSmartFormattingEnabled = AppGroupCoordinator.shared.isSmartFormattingOnPasteEnabled
    @State private var isKeepInClipboardEnabled = AppGroupCoordinator.shared.isKeepTranscriptInClipboardEnabled
    @State private var isHapticFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled
    @State private var isSoundFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled

    @AppStorage(UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
    private var isAutoAudioCleanupEnabled = false
    @AppStorage(UserDefaultsStorage.Keys.audioRetentionDays)
    private var audioRetentionDays = 7
    @AppStorage(AppGroupCoordinator.isHapticsEnabled, store: UserDefaultsStorage.shared)
    private var isHapticsEnabled = true

    @State private var showAddMode = false

    let selectTranscriptionModelTipSettingsView = SelectTranscriptionModelTipSettingsView()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                // Modes section
                Section("Modes") {
                    
                    ForEach(appState.aiService.modes) { mode in
                        NavigationLink(value: mode) {
                            ModeInfoRow(mode: mode)
                        }
                        .contextMenu {
                            Button {
                                HapticManager.heavyImpact()
                                duplicateMode(mode)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            if appState.aiService.modes.count > 1 {
                                Button(role: .destructive) {
                                    deleteMode(mode)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                HapticManager.heavyImpact()
                                duplicateMode(mode)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                    }
                    
                    // Add New Mode button - only show if models are available
                    if appState.transcriptionManager.hasAvailableTranscriptionModels {
                        Button {
                            HapticManager.lightImpact()
                            showAddMode = true
                        } label: {
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
                        Button {
                            HapticManager.lightImpact()
                            navigationPath.append(SettingsDestination.transcriptionModels)
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.orange)
                                
                                Text("Set Up Transcription Model")
                                    .foregroundStyle(.orange)
                                    .font(.footnote)
                            }
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
                    .onChange(of: isVADEnabled) { _, _ in
                        HapticManager.selectionChanged()
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
                    .onChange(of: isTextFormattingEnabled) { _, _ in
                        HapticManager.selectionChanged()
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
                    NavigationLink(value: SettingsDestination.aiProviders) {
                        Text("AI Providers")
                    }
                    NavigationLink(value: SettingsDestination.promptsSettings) {
                        Text("LLM Prompts")
                    }
                }

                Section("Keyboard") {
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
                        HapticManager.selectionChanged()
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
                        HapticManager.selectionChanged()
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
                        HapticManager.selectionChanged()
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
                        HapticManager.selectionChanged()
                        AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled = newValue
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Session Timeout", selection: $audioSessionTimeout) {
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
                        .onChange(of: audioSessionTimeout) { _, _ in
                            HapticManager.selectionChanged()
                        }

                        Text("Keep microphone session active to allow recording from keyboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
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
                }

                Section("Feedback") {
                    Toggle(isOn: $isHapticsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Haptic Feedback")
                                .font(.body)
                            Text("Vibrations for actions like recording, copying, and deleting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Storage") {

                    Toggle(isOn: $isAutoAudioCleanupEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Automatic Audio Cleanup")
                                .font(.body)
                            Text("Automatically delete old audio files to save space")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isAutoAudioCleanupEnabled) { _, _ in
                        HapticManager.selectionChanged()
                    }

                    if isAutoAudioCleanupEnabled {
                        Picker("Keep Audio Files For", selection: $audioRetentionDays) {
                            Text("1 day").tag(1)
                            Text("3 days").tag(3)
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.menu)
                        .padding(.leading)
                        .tint(.primary)
                        .onChange(of: audioRetentionDays) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    }
                }
                
//                ShortcutsLink()
            }
            .navigationDestination(for: VivaMode.self) { mode in
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
                    PromptsSettings(promptsManager: promptsManager, aiService: appState.aiService)
                case .transcriptionModels:
                    ModelsView()
                case .promptsTemplates:
                    TemplateSelectionView(promptsManager: promptsManager)
//                        .navigationTransition(.zoom(sourceID: "addPrompt", in: promptsTransition))
                case .correctSpelling:
                    WordsDictionaryView()
                case .replacements:
                    ReplacementsView()
                case .aiProviders:
                    AIProviders()
                }
            }
            .navigationDestination(for: UserPrompt.self) { prompt in
                PromptFormView(
                    editingPrompt: prompt,
                    promptsManager: promptsManager,
                    aiService: appState.aiService
                )
            }
            .navigationDestination(isPresented: $showAddMode) {
                ModeEditView(
                    mode: nil,
                    aiService: appState.aiService,
                    promptsManager: promptsManager,
                    transcriptionManager: appState.transcriptionManager,
                    navigationPath: $navigationPath
                )
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") {
                        HapticManager.lightImpact()
                        dismiss()
                    }
                }
            }

        }
        .animation(.default, value: isAutoAudioCleanupEnabled)
        .onAppear {
            if appState.shouldNavigateToModels {
                appState.shouldNavigateToModels = false
                navigationPath.append(SettingsDestination.transcriptionModels)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if navigationPath.isEmpty {
                SiriTipView(intent: ToggleRecordIntent(), isVisible: $displaySiriTip)
                    .padding(.horizontal)
            }
        }
        
        .alert("Prewarm Session Error", isPresented: $showPrewarmError) {
            Button("OK") {
                showPrewarmError = false
            }
        } message: {
            Text(prewarmErrorMessage)
        }
    }
    
    private func deleteMode(_ mode: VivaMode) {
        // Prevent deletion if there's only one mode
        guard appState.aiService.modes.count > 1 else { return }

        HapticManager.heavyImpact()
        appState.aiService.deleteMode(mode)
    }

    private func duplicateMode(_ mode: VivaMode) {
        appState.aiService.duplicateMode(mode)
    }

    // MARK: - Keyboard Recording Session Actions

    private func activateKeyboardRecordingSession() {
        Task {
            HapticManager.lightImpact()
            do {
                // Start the pre-warm session (same as when receiving deep link)
                try await prewarmManager.startPrewarmSession()

                // Activate keyboard session to notify keyboard that hot mic is ready
                AppGroupCoordinator.shared.activateKeyboardSession(
                    timeoutSeconds: prewarmManager.audioSessionTimeout
                )

            } catch {
                prewarmErrorMessage = "Failed to activate session: \(error.localizedDescription)"
                HapticManager.error()
                showPrewarmError = true
            }
        }
    }
}


#Preview {
    SettingsView()
        .environment(AppState())
}


// MARK: - Mode Info Row

private struct ModeInfoRow: View {
    let mode: VivaMode

    private var transcriptionModelDisplayName: String {
        mode.transcriptionProvider.getTranscriptionModelDisplayName(mode.transcriptionModel)
    }
    
    private var isLanguageSelectionAvailable: Bool {
        let provider = mode.transcriptionProvider
        let modelName = mode.transcriptionModel

        // Gemini always auto-detects
        if provider == .gemini { return false }

        // Parakeet V3 auto-detects, V2 needs language param
        if provider == .parakeet {
            return modelName == "parakeet-tdt-0.6b-v2"
        }

        return true
    }
    
    private var transcriptionLanguageView: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe")
                .font(.system(size: 8))
            if let languageCode = mode.transcriptionLanguage, isLanguageSelectionAvailable {
                Text(TranscriptionModelProvider.allLanguages[languageCode] ?? languageCode)
            } else {
                Text("Auto")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode.name)
                .font(.body.weight(.medium))

            if !mode.transcriptionModel.isEmpty {
                HStack(alignment: .top) {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "waveform")
                            .foregroundStyle(
                                MeshGradient(
                                    width: 2,
                                    height: 2,
                                    points: [
                                        [0, 0], [1, 0],
                                        [0, 1], [1, 1]
                                    ],
                                    colors: [
                                        .blue, .cyan,
                                        .teal, .mint
                                    ]
                                )
                            )
                            .accessibilityLabel("Transcription provider")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.transcriptionProvider.displayName)
                                .foregroundStyle(.secondary)
                            Text(transcriptionModelDisplayName)
                                .foregroundStyle(.tertiary)
                            transcriptionLanguageView
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if let provider = mode.aiProvider {
                        Divider()
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(
                                    MeshGradient(
                                        width: 2,
                                        height: 2,
                                        points: [
                                            [0, 0], [1, 0],
                                            [0, 1], [1, 1]
                                        ],
                                        colors: [
                                            .purple, .red,
                                            .blue, .pink
                                        ]
                                    )
                                )
                                .accessibilityLabel("AI enhancement provider")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .foregroundStyle(.secondary)
                                Text(mode.aiModel)
                                    .foregroundStyle(.tertiary)
                                if let prompt = mode.userPrompt {
                                    Text(prompt.title)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                .font(.caption2)
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

enum SettingsError: LocalizedError {
    case duplicateModeName(String)
    case duplicatePromptName(String)
    case unexpectedError(String)

    var errorDescription: String? {
        switch self {
        case .duplicateModeName(_):
            "Invalid Mode Name"
        case .duplicatePromptName(_):
            "Invalid Prompt Name"
        case .unexpectedError(_):
            "Unexpected Error"
        }
    }

    var failureReason: String {
        switch self {
        case .duplicateModeName(let name):
            "There's already an existing Mode with name \(name). Enter a different name for this mode."
        case .duplicatePromptName(let name):
            "There's already an existing Prompt with name \(name). Enter a different name for this prompt."
        case .unexpectedError(let message):
            "An unexpected error occurred: \(message). Please try again."
        }
    }
}
