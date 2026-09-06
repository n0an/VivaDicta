//
//  AdvancedSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.08
//

import SwiftUI
import AppGroup
import CloudTranscription

enum AppendWithVoiceStyle: String, CaseIterable, Identifiable {
    case toolbar
    case floatingButton

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toolbar: "Toolbar"
        case .floatingButton: "Floating Button"
        }
    }
}

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage(UserDefaultsStorage.Keys.appendWithVoiceStyle)
    private var appendWithVoiceStyleRaw: String = AppendWithVoiceStyle.toolbar.rawValue

    @AppStorage(UserDefaultsStorage.Keys.isChatEnabled)
    private var isChatEnabled: Bool = true

    @AppStorage(UserDefaultsStorage.Keys.isLiveTranslationEnabled)
    private var isLiveTranslationEnabled: Bool = true

    @AppStorage(UserDefaultsStorage.Keys.isAutoShareAfterRecordingEnabled)
    private var isAutoShareAfterRecordingEnabled: Bool = false

    @AppStorage(UserDefaultsStorage.Keys.isStripTrailingPeriodEnabled)
    private var isStripTrailingPeriodEnabled: Bool = false

    @AppStorage(UserDefaultsStorage.Keys.isFillerRemovalEnabled)
    private var isFillerRemovalEnabled: Bool = true

    @AppStorage(UserDefaultsStorage.Keys.defaultAIModeId)
    private var defaultAIModeId: String = ""

    @AppStorage(AppGroupCoordinator.kGeminiTranscriptionThinkingLevel, store: UserDefaultsStorage.shared)
    private var geminiThinkingLevel: GeminiTranscriptionService.ThinkingLevel = .low

    private var appendWithVoiceStyle: Binding<AppendWithVoiceStyle> {
        Binding(
            get: {
                AppendWithVoiceStyle(rawValue: appendWithVoiceStyleRaw) ?? .toolbar
            },
            set: { newValue in
                appendWithVoiceStyleRaw = newValue.rawValue
            }
        )
    }

    /// Modes that have AI processing enabled and a provider/model configured
    /// (a preset is not required - the user picks one in the AI Actions sheet).
    ///
    /// Must use the same `requirePreset: false` filter as the AI Actions sheet's
    /// `availableModes` (`TranscriptionDetailView`). The sheet only honors a saved
    /// default when that mode is still present in its `availableModes`, so if these
    /// two filters ever diverge the default could silently never apply.
    private var aiConfiguredModes: [VivaMode] {
        appState.aiService.modes.filter {
            appState.aiService.isProperlyConfigured(for: $0, requirePreset: false)
        }
    }

    /// Falls back to "None" when the stored mode no longer exists or no longer
    /// has AI configured, so the picker never shows a stale/blank selection.
    private var defaultAIMode: Binding<String> {
        Binding(
            get: {
                aiConfiguredModes.contains { $0.id.uuidString == defaultAIModeId }
                    ? defaultAIModeId
                    : ""
            },
            set: { newValue in
                defaultAIModeId = newValue
            }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Append with Voice", selection: appendWithVoiceStyle) {
                        ForEach(AppendWithVoiceStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .onChange(of: appendWithVoiceStyle.wrappedValue) { _, _ in
                        HapticManager.selectionChanged()
                    }
                    Text("Choose how to access the Append with Voice action on a note. Toolbar puts it inside the pencil menu in the bottom action bar; Floating Button shows a microphone shortcut in the bottom-right corner.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Picker("Default AI Mode", selection: defaultAIMode) {
                        Text("None").tag("")
                        ForEach(aiConfiguredModes) { mode in
                            Text(mode.name).tag(mode.id.uuidString)
                        }
                    }
                    .onChange(of: defaultAIMode.wrappedValue) { _, _ in
                        HapticManager.selectionChanged()
                    }
                    Text("Mode pre-selected for AI actions in a note when the current mode has no AI processing. You can still switch modes in the AI Actions sheet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Note Detail")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Chats", isOn: $isChatEnabled)
                        .onChange(of: isChatEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Show chat buttons on the main screen and in note detail. Disable to hide chat buttons across the app. Siri Shortcuts and deep links can still open chats.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Live Translation", isOn: $isLiveTranslationEnabled)
                        .onChange(of: isLiveTranslationEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Show the Live Translation button in the main screen toolbar. Disable to hide it if you don't use live translation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Auto Share Note", isOn: $isAutoShareAfterRecordingEnabled)
                        .onChange(of: isAutoShareAfterRecordingEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Open the share sheet automatically with the note's text as soon as it finishes transcribing in the app. Notes captured from the keyboard, Watch, or extensions are unaffected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Features")
            }

            Section {
                Picker(selection: $geminiThinkingLevel) {
                    Text("Low").tag(GeminiTranscriptionService.ThinkingLevel.low)
                    Text("Medium").tag(GeminiTranscriptionService.ThinkingLevel.medium)
                    Text("High").tag(GeminiTranscriptionService.ThinkingLevel.high)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gemini Thinking Level")
                            .font(.body)
                        Text("How much Gemini reasons before answering. Low is fastest and cheapest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: geminiThinkingLevel) { _, _ in
                    HapticManager.selectionChanged()
                }

                NavigationLink(value: SettingsDestination.geminiTranscriptionPrompt) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gemini Transcription Prompt")
                            .font(.body)
                        Text("Customize the instruction sent with the audio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Transcription")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Remove Filler Words", isOn: $isFillerRemovalEnabled)
                        .onChange(of: isFillerRemovalEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Strips hesitation sounds like \"uh\", \"um\", \"ähm\" from transcripts, matched to the transcript's language. Disable to keep them verbatim. Applies to all modes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Trim Trailing Period", isOn: $isStripTrailingPeriodEnabled)
                        .onChange(of: isStripTrailingPeriodEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Strips trailing \".\" or \"...\" from transcripts so casual messages like \"Okay.\" don't read as cold. Applies to all modes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Text Processing")
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AdvancedSettingsView()
    }
    .environment(AppState())
}
#endif
