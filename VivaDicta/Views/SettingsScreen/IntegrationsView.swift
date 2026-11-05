//
//  IntegrationsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.25
//

import SwiftUI
import AppGroup

/// Settings screen for third-party integrations: Obsidian and Webhooks.
/// Two sibling toggles control the Obsidian hand-off:
/// "Auto-open after transcription" (`isObsidianGloballyEnabled`) drives the
/// automatic open in `RecordViewModel.openObsidianIfEnabled` and gates the
/// per-mode opt-out in `ModeEditView`; "Show Send to Obsidian button"
/// (`isObsidianSendButtonEnabled`) reveals a manual send button on the
/// transcription detail screen. The note-name template and the optional custom
/// URL template are shared by both. Webhooks are listed in their own section
/// (`WebhooksSection`) and picked per mode in `ModeEditView`.
struct IntegrationsView: View {
    @AppStorage(UserDefaultsStorage.Keys.isObsidianGloballyEnabled)
    private var isObsidianAutoOpenEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.isObsidianSendButtonEnabled)
    private var isObsidianSendButtonEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.obsidianNoteTemplate)
    private var obsidianNoteTemplate = UserDefaultsStorage.defaultObsidianNoteTemplate

    @AppStorage(UserDefaultsStorage.Keys.isObsidianCustomURLEnabled)
    private var isObsidianCustomURLEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.obsidianCustomURLTemplate)
    private var obsidianCustomURLTemplate = ""

    @State private var webhookSheetTarget: WebhookSheetTarget?

    private static let customURLExample = "obsidian://open?file=Daily%2F{date}&prepend={text}"

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
                    Toggle(isOn: $isObsidianCustomURLEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom URL")
                                .font(.body)
                            Text("Write the whole URL yourself, e.g. to prepend to a daily note or use the Advanced URI plugin.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isObsidianCustomURLEnabled) { _, _ in
                        HapticManager.selectionChanged()
                    }

                    if isObsidianCustomURLEnabled {
                        TextField(Self.customURLExample, text: $obsidianCustomURLTemplate, axis: .vertical)
                            .lineLimit(2...6)
                            .font(.callout.monospaced())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
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

            WebhooksSection(sheetTarget: $webhookSheetTarget)
        }
        // Attached to the Form rather than to the Section: sheet modifiers on
        // list content are unreliable, and Settings is itself a full-screen cover.
        .sheet(item: $webhookSheetTarget) { target in
            switch target {
            case .add:
                WebhookEditView(webhook: nil)
            case .edit(let webhook):
                WebhookEditView(webhook: webhook)
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var obsidianFooter: some View {
        if isAnyObsidianEnabled {
            if isObsidianCustomURLEnabled {
                // Verbatim: the literal "%2F" must not be read as a format specifier.
                Text(verbatim: "VivaDicta opens this URL after filling in the placeholders: \(NoteTemplate.placeholderList). {text} is the final text (AI-processed if a preset ran), {original} is the raw transcription. Values are URL-encoded automatically; type literal slashes in paths as %2F. Example for a daily note: \(Self.customURLExample). Any app's URL scheme works. The text is also copied to the clipboard, so &clipboard works too. Leave the field empty to use the standard note.")
            } else {
                Text("An Obsidian note is created for new transcriptions and appended to when an existing note name matches. Placeholders: \(NoteTemplate.placeholderList). To instead append to a daily note, set the name to just {date}. Per-mode opt-out for auto-open is available in each mode's settings. The clipboard is overwritten each time.")
            }
        }
    }
}

/// What the webhook editor sheet is presenting.
private enum WebhookSheetTarget: Identifiable {
    case add
    case edit(WebhookDefinition)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let webhook): webhook.id.uuidString
        }
    }
}

/// Lists the configured webhooks with their last delivery result and asks the
/// parent to open the add / edit sheet.
private struct WebhooksSection: View {
    @Binding var sheetTarget: WebhookSheetTarget?

    private var store: WebhookStore { .shared }

    var body: some View {
        Section {
            ForEach(store.webhooks) { webhook in
                Button {
                    sheetTarget = .edit(webhook)
                } label: {
                    WebhookRow(webhook: webhook, status: store.statuses[webhook.id])
                }
                .tint(.primary)
            }

            Button("Add Webhook", systemImage: "plus") {
                sheetTarget = .add
            }
        } header: {
            Text("Webhooks")
        } footer: {
            Text("After transcription and AI processing, VivaDicta POSTs the note as JSON to the webhook picked in a mode's settings. Works with n8n, Zapier, Make or your own server. Failed deliveries are retried in the background for up to 24 hours.")
        }
    }
}

private struct WebhookRow: View {
    let webhook: WebhookDefinition
    let status: WebhookDeliveryStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(webhook.displayName)
                    .font(.body)
                Spacer()
                if !webhook.isEnabled {
                    Text("Off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(webhook.url.host() ?? webhook.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let status {
                WebhookStatusLabel(status: status)
            }
        }
        .contentShape(.rect)
    }
}
