//
//  IntegrationsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.25
//

import SwiftUI
import AppGroup

/// Settings screen for third-party integrations (Obsidian today; Webhooks /
/// Zapier later). Two sibling toggles control the Obsidian hand-off:
/// "Auto-open after transcription" (`isObsidianGloballyEnabled`) drives the
/// automatic open in `RecordViewModel.openObsidianIfEnabled` and gates the
/// per-mode opt-out in `ModeEditView`; "Show Send to Obsidian button"
/// (`isObsidianSendButtonEnabled`) reveals a manual send button on the
/// transcription detail screen. The note-name template is shared by both.
struct IntegrationsView: View {
    @AppStorage(UserDefaultsStorage.Keys.isObsidianGloballyEnabled)
    private var isObsidianAutoOpenEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.isObsidianSendButtonEnabled)
    private var isObsidianSendButtonEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.obsidianNoteTemplate)
    private var obsidianNoteTemplate = UserDefaultsStorage.defaultObsidianNoteTemplate

    private var isAnyObsidianEnabled: Bool {
        isObsidianAutoOpenEnabled || isObsidianSendButtonEnabled
    }

    var body: some View {
        Form {
            Section(header: Text("Obsidian"),
                    footer: obsidianFooter) {
                Toggle(isOn: $isObsidianAutoOpenEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-open after transcription")
                            .font(.body)
                        Text("Open Obsidian after each transcription and save the text as a note.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isObsidianAutoOpenEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                Toggle(isOn: $isObsidianSendButtonEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Send to Obsidian button")
                            .font(.body)
                        Text("Add a button on each note's detail screen to send a transcription on demand.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isObsidianSendButtonEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                if isAnyObsidianEnabled {
                    HStack {
                        Text("Note name")
                        Spacer()
                        TextField(UserDefaultsStorage.defaultObsidianNoteTemplate, text: $obsidianNoteTemplate)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var obsidianFooter: some View {
        if isAnyObsidianEnabled {
            Text("An Obsidian note is created for new transcriptions and appended to when an existing note name matches. Placeholders: {date}, {yyyy}, {MM}, {dd}, {HH}, {mm}, {ss}, {preset}, {mode}. To instead append to a daily note, set the name to just {date}. Per-mode opt-out for auto-open is available in each mode's settings. The clipboard is overwritten each time.")
        }
    }
}
