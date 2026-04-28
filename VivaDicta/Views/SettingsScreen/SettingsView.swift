//
//  SettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI
import AppIntents
import TipKit
import MessageUI

struct SettingsView: View {
    @Environment(AppState.self) var appState

    @State var promptsManager = PromptsManager()

    @Environment(\.dismiss) private var dismiss
    @State var navigationPath = NavigationPath()
    @AppStorage(AppGroupCoordinator.kIsVADEnabled, store: UserDefaultsStorage.shared)
    private var isVADEnabled = true
    @AppStorage(AppGroupCoordinator.kIsSpeakerDiarizationEnabled, store: UserDefaultsStorage.shared)
    private var isSpeakerDiarizationEnabled = false
    @AppStorage(UserDefaultsStorage.Keys.isAutoCopyAfterRecordingEnabled)
    private var isAutoCopyAfterRecordingEnabled = false
    @AppStorage(UserDefaultsStorage.Keys.isAutoReminderExtractionEnabled, store: UserDefaultsStorage.appPrivate)
    private var isAutoReminderExtractionEnabled = false
    @AppStorage("preferredChineseScript") private var chineseScriptPreference: ChineseScriptPreference = .auto
    @AppStorage(UserDefaultsStorage.Keys.audioSessionTimeout)
    private var audioSessionTimeout: Int = 180
    private let prewarmManager = AudioPrewarmManager.shared
    @State private var showPrewarmError = false
    @State private var prewarmErrorMessage = ""
    
    @AppStorage(UserDefaultsStorage.Keys.displaySiriTip) private var displaySiriTip: Bool = true
    @State private var isKeepInClipboardEnabled = AppGroupCoordinator.shared.isKeepTranscriptInClipboardEnabled
    @State private var isHapticFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled
    @State private var isSoundFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled
    @State private var keyboardLayoutStyle: KeyboardLayoutStyle = AppGroupCoordinator.shared.keyboardLayoutStyle

    @AppStorage(UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
    private var isAutoAudioCleanupEnabled = false
    @AppStorage(UserDefaultsStorage.Keys.audioRetentionDays)
    private var audioRetentionDays = 7

    @AppStorage(UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
    private var isAutoNoteCleanupEnabled = false
    @AppStorage(UserDefaultsStorage.Keys.noteRetentionDays)
    private var noteRetentionDays = 7

    @AppStorage(UserDefaultsStorage.Keys.isAutoChatCleanupEnabled)
    private var isAutoChatCleanupEnabled = false
    @AppStorage(UserDefaultsStorage.Keys.chatRetentionDays)
    private var chatRetentionDays = 7

    @AppStorage(UserDefaultsStorage.Keys.isICloudSyncEnabled)
    private var isICloudSyncEnabled = true
    @AppStorage(MarkdownExportContent.userDefaultsKey)
    private var markdownExportContent: MarkdownExportContent = .default
    @State private var showRestartAlert = false
    @AppStorage(AppGroupCoordinator.isHapticsEnabled, store: UserDefaultsStorage.shared)
    private var isHapticsEnabled = true

    @State private var showAddMode = false
    @State private var showMailCompose = false

    let selectTranscriptionModelTipSettingsView = SelectTranscriptionModelTipSettingsView()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                // Modes section
                Section("Modes") {
                    
                    ForEach(appState.aiService.modes) { mode in
                        NavigationLink(value: mode) {
                            ModeInfoRow(mode: mode, connectedProviders: appState.aiService.connectedProviders, presetManager: appState.presetManager)
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

                    Toggle(isOn: $isSpeakerDiarizationEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speaker Labels")
                                .font(.body)
                            Text("Identify and label different speakers for local Whisper, Deepgram, Mistral, and Soniox")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isSpeakerDiarizationEnabled) { _, _ in
                        HapticManager.selectionChanged()
                    }

                    Toggle(isOn: $isAutoCopyAfterRecordingEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Copy to Clipboard")
                                .font(.body)
                            Text("Automatically copy transcription to clipboard after recording")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isAutoCopyAfterRecordingEnabled) { _, _ in
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
                
                Section("Organization") {
                    NavigationLink(value: SettingsDestination.tags) {
                        Label("Tags", systemImage: "tag")
                    }
                }

                Section("AI Settings") {
                    NavigationLink(value: SettingsDestination.aiProviders) {
                        Text("AI Providers")
                    }
                    NavigationLink(value: SettingsDestination.presetsSettings) {
                        Text("AI Processing Presets")
                    }
                    Toggle(isOn: $isAutoReminderExtractionEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Extract Reminder Suggestions Automatically")
                                .font(.body)
                            Text("After saving a new note, detect reminder-worthy tasks in the background and keep them ready for review.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isAutoReminderExtractionEnabled) { _, _ in
                        HapticManager.selectionChanged()
                    }
                    if ChineseScriptPreferenceStore.shouldShowSetting(modes: appState.aiService.modes) {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("Chinese Script", selection: $chineseScriptPreference) {
                                ForEach(ChineseScriptPreference.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.primary)
                            Text("Applied to AI-enhanced output when it's in Chinese.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .onChange(of: chineseScriptPreference) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    }
                    NavigationLink(value: SettingsDestination.chatTools) {
                        HStack {
                            Text("Chat Tools")
                        }
                    }
                }

                Section("Smart Search") {
                    NavigationLink(value: SettingsDestination.smartSearch) {
                        HStack {
                            Text("Smart Search")
                            Spacer()
                            Text("^[\(RAGIndexingService.shared.indexedTranscriptionCount) note](inflect: true)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Keyboard") {
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
                    }
                    .onChange(of: isHapticFeedbackEnabled) { _, newValue in
                        HapticManager.selectionChanged()
                        AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled = newValue
                    }

                    Toggle(isOn: $isSoundFeedbackEnabled) {
                        Text("Sound")
                            .font(.body)
                    }
                    .onChange(of: isSoundFeedbackEnabled) { _, newValue in
                        HapticManager.selectionChanged()
                        AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled = newValue
                    }

                    Picker("Layout", selection: $keyboardLayoutStyle) {
                        ForEach(KeyboardLayoutStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .onChange(of: keyboardLayoutStyle) { _, newValue in
                        HapticManager.selectionChanged()
                        AppGroupCoordinator.shared.keyboardLayoutStyle = newValue
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Session Timeout", selection: $audioSessionTimeout) {
                            #if DEBUG
                            Text("15 seconds").tag(15)
                            Text("30 seconds").tag(30)
                            Text("60 seconds").tag(60)
                            Text("90 seconds").tag(90)
                            Text("2 minutes").tag(120)
                            #endif
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

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("Markdown Export", selection: $markdownExportContent) {
                            ForEach(MarkdownExportContent.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                        Text("Choose what to include when exporting notes as Markdown.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: markdownExportContent) { _, _ in
                        HapticManager.selectionChanged()
                    }
                } header: {
                    Text("Export")
                }

                Section("Storage") {

                    Toggle(isOn: $isAutoNoteCleanupEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-delete Notes")
                                .font(.body)
                            Text("Automatically delete old notes and their audio files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isAutoNoteCleanupEnabled) { _, newValue in
                        HapticManager.selectionChanged()
                        if newValue {
                            isAutoAudioCleanupEnabled = false
                        }
                    }

                    if isAutoNoteCleanupEnabled {
                        Picker("Keep Notes For", selection: $noteRetentionDays) {
                            Text("1 day").tag(1)
                            Text("3 days").tag(3)
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.menu)
                        .padding(.leading)
                        .tint(.primary)
                        .onChange(of: noteRetentionDays) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    }

                    if !isAutoNoteCleanupEnabled {
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

                    Toggle(isOn: $isAutoChatCleanupEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-delete Chats")
                                .font(.body)
                            Text("Automatically delete old chat conversations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isAutoChatCleanupEnabled) { _, _ in
                        HapticManager.selectionChanged()
                    }

                    if isAutoChatCleanupEnabled {
                        Picker("Keep Chats For", selection: $chatRetentionDays) {
                            Text("1 day").tag(1)
                            Text("3 days").tag(3)
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.menu)
                        .padding(.leading)
                        .tint(.primary)
                        .onChange(of: chatRetentionDays) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $isICloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync")
                                .font(.body)
                            Text("Sync transcriptions, dictionary, and replacements across devices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isICloudSyncEnabled) { _, _ in
                        HapticManager.selectionChanged()
                        showRestartAlert = true
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Requires app restart to take effect.")
                }

                Section("Integrations") {
                    NavigationLink(value: SettingsDestination.integrations) {
                        HStack {
                            Image(systemName: "puzzlepiece.extension")
                                .foregroundStyle(.purple)
                            Text("Integrations")
                        }
                    }
                }

                Section("Support") {
                    Link(destination: URL(string: "https://vivadicta.com/ios/docs")!) {
                        HStack {
                            Image(systemName: "book")
                                .foregroundStyle(.purple)
                            Text("Documentation")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMailCompose = true
                        } else {
                            openSupportEmailFallback()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundStyle(.blue)
                            Text("Email Support")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        requestAppStoreReview()
                    } label: {
                        HStack {
                            Image(systemName: "star")
                                .foregroundStyle(.yellow)
                            Text("Review in App Store")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ShareLink(item: URL(string: "https://apps.apple.com/app/id6758147238")!) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.green)
                            Text("Share VivaDicta")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(for: VivaMode.self) { mode in
                ModeEditView(
                    mode: mode,
                    aiService: appState.aiService,
                    presetManager: appState.presetManager,
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
                case .presetsSettings:
                    PresetSettings(presetManager: appState.presetManager)
                case .correctSpelling:
                    WordsDictionaryView()
                case .replacements:
                    ReplacementsView()
                case .aiProviders:
                    AIProviders()
                case .tags:
                    TagManagementView()
                case .chatTools:
                    ChatToolsSettingsView()
                case .smartSearch:
                    SmartSearchSettingsView()
                case .integrations:
                    IntegrationsView()
                }
            }
            .navigationDestination(for: Preset.self) { preset in
                PresetFormView(preset: preset, presetManager: appState.presetManager)
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
                    presetManager: appState.presetManager,
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
                    .accessibilityLabel("Close Settings")
                }
            }

        }
        .animation(.default, value: isAutoAudioCleanupEnabled)
        .animation(.default, value: isAutoNoteCleanupEnabled)
        .onAppear {
            if appState.shouldNavigateToModels {
                appState.shouldNavigateToModels = false
                navigationPath.append(SettingsDestination.transcriptionModels)
            }
            if appState.shouldNavigateToModeSettings {
                appState.shouldNavigateToModeSettings = false
                navigationPath.append(appState.aiService.selectedMode)
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
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Restart Now") {
                exit(0)
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("The app needs to restart for iCloud sync changes to take effect.")
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                subject: "VivaDicta Support Request",
                recipients: ["support@vivadicta.com"],
                body: supportEmailBody
            )
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

    // MARK: - Support

    private var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }

    private var supportEmailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let deviceModel = deviceModelIdentifier
        let systemVersion = UIDevice.current.systemVersion

        return """

---
Please describe your issue above this line
---
App Version: \(appVersion) (\(buildNumber))
Device: \(deviceModel)
iOS Version: \(systemVersion)
"""
    }

    private func requestAppStoreReview() {
        if let url = URL(string: "https://apps.apple.com/app/id6758147238?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private func openSupportEmailFallback() {
        let subject = "VivaDicta Support Request"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = supportEmailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@vivadicta.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
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

#if DEBUG
#Preview {
    SettingsView()
        .environment(AppState())
}
#endif

// MARK: - Mode Info Row

private struct ModeInfoRow: View {
    let mode: VivaMode
    let connectedProviders: [AIProvider]
    let presetManager: PresetManager

    private var isTranscriptionProviderAvailable: Bool {
        guard let aiProvider = mode.transcriptionProvider.mappedAIProvider else {
            // On-device providers (WhisperKit, Parakeet) or custom are always available
            return true
        }
        return connectedProviders.contains(aiProvider)
    }

    private var transcriptionModelDisplayName: String {
        // For custom transcription, show the actual configured model name
        if mode.transcriptionProvider == .customTranscription {
            let manager = CustomTranscriptionModelManager.shared
            return manager.isConfigured ? manager.customModel.modelName : "Custom"
        }
        return mode.transcriptionProvider.getTranscriptionModelDisplayName(mode.transcriptionModel)
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

    private var reminderExtractorSummary: String? {
        guard let provider = mode.reminderExtractorProvider else { return nil }
        if let model = mode.reminderExtractorModel, !model.isEmpty, provider != .apple {
            return "Reminders: \(provider.displayName) - \(model)"
        }
        return "Reminders: \(provider.displayName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode.name)
                .font(.body.weight(.medium))

            if !mode.transcriptionModel.isEmpty && isTranscriptionProviderAvailable {
                HStack(alignment: .top, spacing: 0) {
                    // Transcription info - takes 50% width
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
                                        .blue, .green,
                                        .indigo, .teal
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Enhancement info - takes 50% width
                    if let provider = mode.aiProvider, connectedProviders.contains(provider) {
                        Divider()
                            .padding(.trailing, 8)
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
                                .accessibilityLabel("AI processing provider")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .foregroundStyle(.secondary)
                                Text(mode.aiModel)
                                    .foregroundStyle(.tertiary)
                                if let presetId = mode.presetId {
                                    Text(presetManager.preset(for: presetId)?.name
                                         ?? PresetCatalog.displayName(for: presetId, fallback: presetId))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.caption2)
                .padding(.leading, 4)
            }

            if let reminderExtractorSummary {
                Label(reminderExtractorSummary, systemImage: "checklist")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let body: String

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setSubject(subject)
        mailComposer.setToRecipients(recipients)
        mailComposer.setMessageBody(body, isHTML: false)
        return mailComposer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
