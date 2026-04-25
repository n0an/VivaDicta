//
//  IntegrationsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.25
//

import SwiftUI

/// Settings screen for third-party integrations (Obsidian today; Webhooks /
/// Zapier later). The master Obsidian toggle here gates the per-mode toggle
/// in `ModeEditView`; flipping it off hides per-mode controls and short-
/// circuits the hand-off in `RecordViewModel.openObsidianIfEnabled`.
struct IntegrationsView: View {
    @AppStorage(UserDefaultsStorage.Keys.isObsidianGloballyEnabled)
    private var isObsidianGloballyEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.obsidianNoteTemplate)
    private var obsidianNoteTemplate = UserDefaultsStorage.defaultObsidianNoteTemplate

    var body: some View {
        Form {
            Section(header: Text("Obsidian"),
                    footer: obsidianFooter) {
                Toggle(isOn: $isObsidianGloballyEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Save to Obsidian")
                            .font(.body)
                        Text("After each transcription, open Obsidian and save the text as a note.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isObsidianGloballyEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                if isObsidianGloballyEnabled {
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
        if isObsidianGloballyEnabled {
            Text("A new Obsidian note is created for each transcription. Placeholders: {date}, {yyyy}, {MM}, {dd}, {HH}, {mm}, {ss}, {preset}, {mode}. To instead append to a daily note, set the name to just {date}. Per-mode opt-out is available in each mode's settings. The clipboard is overwritten each time.")
        }
    }
}
