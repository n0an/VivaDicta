//
//  IntegrationsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.25
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings screen for third-party integrations (Obsidian today; Webhooks /
/// Zapier later). The master Obsidian toggle here gates the per-mode toggle
/// in `ModeEditView`; flipping it off hides per-mode controls and short-
/// circuits the hand-off in `RecordViewModel.openObsidianIfEnabled`.
struct IntegrationsView: View {
    @AppStorage(UserDefaultsStorage.Keys.isObsidianGloballyEnabled)
    private var isObsidianGloballyEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.obsidianNoteTemplate)
    private var obsidianNoteTemplate = UserDefaultsStorage.defaultObsidianNoteTemplate

    @AppStorage(UserDefaultsStorage.Keys.isFolderExportGloballyEnabled)
    private var isFolderExportGloballyEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.folderExportDisplayName)
    private var folderExportDisplayName: String = ""

    @State private var isFolderPickerPresented = false
    @State private var folderPickerError: String?

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

            Section(header: Text("Save to Folder"),
                    footer: folderExportFooter) {
                Toggle(isOn: $isFolderExportGloballyEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Save markdown file")
                            .font(.body)
                        Text("After each transcription, silently save a .md file to a folder of your choice (e.g. an Obsidian vault in iCloud Drive).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isFolderExportGloballyEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                if isFolderExportGloballyEnabled {
                    Button {
                        isFolderPickerPresented = true
                    } label: {
                        HStack {
                            Text(folderExportDisplayName.isEmpty ? "Choose folder..." : "Folder")
                            Spacer()
                            if !folderExportDisplayName.isEmpty {
                                Text(folderExportDisplayName)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

                    if !folderExportDisplayName.isEmpty {
                        Button("Clear folder", role: .destructive) {
                            FolderExportService.clearBookmark()
                            folderExportDisplayName = ""
                        }
                    }
                }
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    folderPickerError = "Could not access the selected folder."
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    try FolderExportService.storeBookmark(for: url)
                } catch {
                    folderPickerError = error.localizedDescription
                }
            case .failure(let error):
                folderPickerError = error.localizedDescription
            }
        }
        .alert("Folder selection failed",
               isPresented: Binding(
                   get: { folderPickerError != nil },
                   set: { if !$0 { folderPickerError = nil } }
               ),
               presenting: folderPickerError) { _ in
            Button("OK", role: .cancel) { folderPickerError = nil }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var obsidianFooter: some View {
        if isObsidianGloballyEnabled {
            Text("A new Obsidian note is created for each transcription. Placeholders: {date}, {yyyy}, {MM}, {dd}, {HH}, {mm}, {ss}, {preset}, {mode}. To instead append to a daily note, set the name to just {date}. Per-mode opt-out is available in each mode's settings. The clipboard is overwritten each time.")
        }
    }

    @ViewBuilder
    private var folderExportFooter: some View {
        if isFolderExportGloballyEnabled {
            Text("One markdown file per transcription, named VivaDicta-YYYY-MM-DD_HHmmss.md. Pick any folder, including an iCloud Drive Obsidian vault. Per-mode opt-out is available in each mode's settings. Saving from the keyboard requires Full Access.")
        }
    }
}
