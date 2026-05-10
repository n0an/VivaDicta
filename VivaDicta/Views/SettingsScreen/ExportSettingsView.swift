//
//  ExportSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.09
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings screen for the markdown folder-export integration. Two sibling
/// toggles control the hand-off:
/// - "Auto-export after transcription" (`isFolderExportGloballyEnabled`) drives
///   the silent post-transcription save in `FolderExportService.saveIfEnabled`
///   and gates the per-mode opt-out in `ModeEditView`.
/// - "Show Export to Folder button" (`isFolderExportButtonEnabled`) reveals a
///   manual export FAB on the transcription detail screen.
/// The folder picker and Markdown Export variation picker are shared.
struct ExportSettingsView: View {
    @AppStorage(MarkdownExportContent.userDefaultsKey)
    private var markdownExportContent: MarkdownExportContent = .default

    @AppStorage(UserDefaultsStorage.Keys.isFolderExportGloballyEnabled)
    private var isFolderExportAutoEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.isFolderExportButtonEnabled)
    private var isFolderExportButtonEnabled = false

    @AppStorage(UserDefaultsStorage.SharedKeys.folderExportDisplayName, store: UserDefaultsStorage.shared)
    private var folderExportDisplayName: String = ""

    @State private var isFolderPickerPresented = false
    @State private var folderPickerError: String?

    private var isAnyExportEnabled: Bool {
        isFolderExportAutoEnabled || isFolderExportButtonEnabled
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Markdown Export", selection: $markdownExportContent) {
                        ForEach(MarkdownExportContent.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    Text("Choose what to include when exporting notes as Markdown. Applies to manual share, the Export to Folder button, and the auto-export below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: markdownExportContent) { _, _ in
                    HapticManager.selectionChanged()
                }
            }

            Section(header: Text("Folder Export"), footer: exportFooter) {
                Toggle(isOn: $isFolderExportAutoEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-export after transcription")
                            .font(.body)
                        Text("After each transcription, silently save a .md file to the folder you pick below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isFolderExportAutoEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                Toggle(isOn: $isFolderExportButtonEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Export to Folder button")
                            .font(.body)
                        Text("Add a button on each note's detail screen to save the markdown file to the folder on demand.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isFolderExportButtonEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                if isAnyExportEnabled {
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
        .navigationTitle("Export Notes")
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
    private var exportFooter: some View {
        if isAnyExportEnabled {
            Text("One markdown file per transcription, named VivaDicta-YYYY-MM-DD_HHmmss.md. Pick any folder, including an Obsidian vault. Per-mode opt-out for auto-export is available in each mode's settings.")
        }
    }
}
