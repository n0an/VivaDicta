//
//  ExportSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.09
//

import SwiftUI
import AppGroup
import UniformTypeIdentifiers

/// Settings screen for the markdown folder-export integration. Two sibling
/// toggles control the hand-off:
/// - "Auto-export after transcription" (`isFolderExportGloballyEnabled`) drives
///   the silent post-transcription save in `FolderExportService.saveIfEnabled`
///   and gates the per-mode opt-out in `ModeEditView`.
/// - "Show Export to Folder button" (`isFolderExportButtonEnabled`) reveals a
///   manual export FAB on the transcription detail screen.
/// The folder picker, Markdown Export variation picker and the file section
/// (name template, write mode, entry template) are shared.
struct ExportSettingsView: View {
    @AppStorage(MarkdownExportContent.userDefaultsKey)
    private var markdownExportContent: MarkdownExportContent = .default

    @AppStorage(UserDefaultsStorage.Keys.isFolderExportGloballyEnabled)
    private var isFolderExportAutoEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.isFolderExportButtonEnabled)
    private var isFolderExportButtonEnabled = false

    @AppStorage(UserDefaultsStorage.SharedKeys.folderExportDisplayName, store: UserDefaultsStorage.shared)
    private var folderExportDisplayName: String = ""

    @AppStorage(UserDefaultsStorage.Keys.folderExportFilenameTemplate)
    private var filenameTemplate = UserDefaultsStorage.defaultFolderExportFilenameTemplate

    @AppStorage(UserDefaultsStorage.Keys.folderExportWriteMode)
    private var writeMode: FolderExportWriteMode = .default

    @AppStorage(UserDefaultsStorage.Keys.folderExportEntryTemplate)
    private var entryTemplate = UserDefaultsStorage.defaultFolderExportEntryTemplate

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

            if isAnyExportEnabled {
                Section(header: Text("File"), footer: fileFooter) {
                    HStack {
                        Text("File name")
                        Spacer()
                        TextField(UserDefaultsStorage.defaultFolderExportFilenameTemplate, text: $filenameTemplate)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Picker("If the file exists", selection: $writeMode) {
                        ForEach(FolderExportWriteMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .onChange(of: writeMode) { _, _ in
                        HapticManager.selectionChanged()
                    }

                    if writeMode != .replace {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry")
                            TextField(UserDefaultsStorage.defaultFolderExportEntryTemplate, text: $entryTemplate, axis: .vertical)
                                .lineLimit(2...8)
                                .font(.callout.monospaced())
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
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
            Text("Pick any folder, including an Obsidian vault. Per-mode opt-out for auto-export is available in each mode's settings.")
        }
    }

    @ViewBuilder
    private var fileFooter: some View {
        switch writeMode {
        case .replace:
            Text("One markdown file per name. Placeholders: \(NoteTemplate.placeholderList). A / creates subfolders, e.g. Daily/{date}. .md is added if missing. With a name unique per note (the default includes seconds) every transcription gets its own file; exporting the same note again overwrites it.")
        case .append, .prepend:
            Text("Each transcription is added as an entry to the file, e.g. File name Daily/{date} collects a whole day in one note. \(writeMode == .prepend ? "New entries go on top, below any YAML frontmatter." : "New entries go at the end.") Entry placeholders: \(NoteTemplate.placeholderList), plus {markdown} for the full export with variations. {text} is the final text, {original} the raw transcription. Entries carry hidden markers, so exporting the same note again updates its entry instead of adding a copy.")
        }
    }
}
