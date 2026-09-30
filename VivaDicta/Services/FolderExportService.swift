//
//  FolderExportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.03
//

import Foundation
import AppGroup
import os

/// Silently writes each transcription as a markdown file into a user-picked
/// folder (e.g. an Obsidian vault inside iCloud Drive). The folder is selected
/// once via `UIDocumentPickerViewController` and remembered as a security-scoped
/// bookmark stored in the App Group, so the keyboard extension can write too.
///
/// Mirrors the existing Obsidian integration: gated by a global toggle plus a
/// per-mode toggle, and triggered at the same points in `RecordViewModel`.
enum FolderExportService {
    nonisolated private static let logger = Logger(category: .folderExportService)

    // MARK: - Bookmark management

    /// Stores the user-picked folder as a security-scoped bookmark in the App
    /// Group so it is resolvable from the keyboard extension as well.
    /// The picker URL must already be security-scoped (caller is responsible
    /// for `startAccessingSecurityScopedResource()` around bookmark creation).
    static func storeBookmark(for url: URL) throws {
        // iOS does not support `.withSecurityScope` (macOS-only). Picker URLs
        // from `UIDocumentPickerViewController` are inherently security-scoped,
        // and the default-options bookmark preserves that on iOS.
        let data = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaultsStorage.shared.set(data, forKey: UserDefaultsStorage.SharedKeys.folderExportBookmark)
        UserDefaultsStorage.shared.set(url.lastPathComponent, forKey: UserDefaultsStorage.SharedKeys.folderExportDisplayName)
    }

    static func clearBookmark() {
        UserDefaultsStorage.shared.removeObject(forKey: UserDefaultsStorage.SharedKeys.folderExportBookmark)
        UserDefaultsStorage.shared.removeObject(forKey: UserDefaultsStorage.SharedKeys.folderExportDisplayName)
    }

    static var displayName: String? {
        UserDefaultsStorage.shared.string(forKey: UserDefaultsStorage.SharedKeys.folderExportDisplayName)
    }

    // MARK: - Saving

    /// Everything the background writer needs, resolved from Settings on the
    /// main actor before hopping off it.
    nonisolated struct WriteRequest: Sendable {
        /// Subfolders followed by the file name, relative to the picked folder.
        let pathComponents: [String]
        let mode: FolderExportWriteMode
        /// Full markdown document for `.replace`, the entry body otherwise.
        let content: String
        /// Transcription UUID used for the block markers.
        let blockID: String

        var relativePath: String { pathComponents.joined(separator: "/") }
    }

    /// Writes the transcription as a markdown file in the picked folder if the
    /// global toggle is on, the mode opts in, and a bookmark exists.
    /// Safe to call from any source. Errors are logged, never thrown to caller.
    @MainActor
    static func saveIfEnabled(transcription: Transcription, mode: VivaMode) {
        guard UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isFolderExportGloballyEnabled) else { return }
        guard mode.folderExportEnabled else { return }
        guard let bookmark = UserDefaultsStorage.shared.data(forKey: UserDefaultsStorage.SharedKeys.folderExportBookmark) else {
            logger.logInfo("📁 Folder export enabled but no folder picked yet - skipping")
            return
        }

        guard let request = makeRequest(for: transcription) else { return }

        Task(priority: .utility) { @concurrent in
            await write(request: request, bookmark: bookmark)
        }
    }

    /// Outcome of a manual export attempt. Distinguishes failures so the UI
    /// can show specific guidance instead of a generic "something went wrong".
    nonisolated enum ManualSaveResult: Equatable, Sendable {
        case success(filename: String)
        case noFolderPicked
        case bookmarkUnusable
        case writeFailed(String)
    }

    /// Manually writes the transcription as a markdown file in the picked
    /// folder. Bypasses the global auto-export toggle and per-mode opt-out
    /// because the user explicitly tapped the Export to Folder button.
    ///
    /// Awaits the actual write (unlike `saveIfEnabled`) so callers can
    /// surface real success or failure to the user instead of giving a
    /// false success signal when the bookmark is stale or access is revoked.
    @MainActor
    static func saveManually(transcription: Transcription) async -> ManualSaveResult {
        guard let bookmark = UserDefaultsStorage.shared.data(forKey: UserDefaultsStorage.SharedKeys.folderExportBookmark) else {
            logger.logInfo("📁 Folder export: manual save requested but no folder picked")
            return .noFolderPicked
        }

        guard let request = makeRequest(for: transcription) else {
            return .writeFailed("The file name template does not produce a usable file name")
        }

        return await Task(priority: .userInitiated) { @concurrent in
            await writeWithResult(request: request, bookmark: bookmark)
        }.value
    }

    /// Resolves the file-name template, write mode and entry template from
    /// Settings for one transcription.
    @MainActor
    private static func makeRequest(for transcription: Transcription) -> WriteRequest? {
        guard let snapshot = TranscriptionMarkdownExportService.snapshots(for: [transcription]).first else { return nil }
        let defaults = UserDefaultsStorage.appPrivate

        let filenameTemplate = nonEmpty(defaults.string(forKey: UserDefaultsStorage.Keys.folderExportFilenameTemplate))
            ?? UserDefaultsStorage.defaultFolderExportFilenameTemplate
        let mode = defaults.string(forKey: UserDefaultsStorage.Keys.folderExportWriteMode)
            .flatMap(FolderExportWriteMode.init(rawValue:)) ?? .default
        let values = TranscriptionMarkdownExportService.templateValues(for: snapshot)

        guard let pathComponents = FolderExportComposer.relativePath(template: filenameTemplate, values: values) else {
            logger.logError("📁 Folder export: template '\(filenameTemplate)' produced no usable file name")
            return nil
        }

        let content: String
        switch mode {
        case .replace:
            content = values.markdown
        case .append, .prepend:
            let entryTemplate = nonEmpty(defaults.string(forKey: UserDefaultsStorage.Keys.folderExportEntryTemplate))
                ?? UserDefaultsStorage.defaultFolderExportEntryTemplate
            content = NoteTemplate.expand(entryTemplate, values: values)
        }

        return WriteRequest(pathComponents: pathComponents, mode: mode, content: content, blockID: values.id)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    @concurrent private static func write(request: WriteRequest, bookmark: Data) async {
        _ = await writeWithResult(request: request, bookmark: bookmark)
    }

    /// Same as `write`, but returns a typed outcome so manual callers can
    /// surface accurate UI feedback (e.g. distinguish "bookmark stale" from
    /// "write failed").
    @concurrent private static func writeWithResult(request: WriteRequest, bookmark: Data) async -> ManualSaveResult {
        var isStale = false
        let folderURL: URL
        do {
            folderURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            logger.logError("📁 Folder export: bookmark resolution failed - \(error.localizedDescription)")
            return .bookmarkUnusable
        }

        if isStale {
            logger.logError("📁 Folder export: bookmark is stale - clearing so the user re-picks")
            await MainActor.run { Self.clearBookmark() }
            return .bookmarkUnusable
        }

        guard folderURL.startAccessingSecurityScopedResource() else {
            logger.logError("📁 Folder export: cannot access \(folderURL.path) - clearing bookmark so the user re-picks")
            await MainActor.run { Self.clearBookmark() }
            return .bookmarkUnusable
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        var destination = folderURL
        for component in request.pathComponents.dropLast() {
            destination = destination.appending(path: component, directoryHint: .isDirectory)
        }
        destination = destination.appending(path: request.pathComponents.last ?? "", directoryHint: .notDirectory)

        // Coordinated read-modify-write: the folder is usually an Obsidian
        // vault in iCloud Drive, and Obsidian or iCloud may touch the same
        // daily file at the same time.
        var outcome: ManualSaveResult = .writeFailed("File coordination did not run")
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forMerging, error: &coordinationError) { url in
            outcome = writeCoordinated(request: request, to: url)
        }
        if let coordinationError {
            logger.logError("📁 Folder export: coordination failed for \(request.relativePath) - \(coordinationError.localizedDescription)")
            return .writeFailed(coordinationError.localizedDescription)
        }
        return outcome
    }

    nonisolated private static func writeCoordinated(request: WriteRequest, to url: URL) -> ManualSaveResult {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

            let text: String
            switch request.mode {
            case .replace:
                // The file name is deterministic per note by default (derived
                // from its timestamp), so re-exporting the same note overwrites
                // its previous file rather than piling up `-2`, `-3` copies.
                text = request.content
            case .append, .prepend:
                var existing: String?
                if fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
                    // Never fall back to an empty string here: a file we cannot
                    // decode would be overwritten and the user's note lost.
                    existing = try String(contentsOf: url, encoding: .utf8)
                }
                text = FolderExportComposer.merge(
                    existing: existing,
                    entry: request.content,
                    id: request.blockID,
                    mode: request.mode
                )
            }

            try Data(text.utf8).write(to: url, options: .atomic)
            logger.logInfo("📁 Folder export: wrote \(request.relativePath) (\(request.mode.rawValue))")
            return .success(filename: request.relativePath)
        } catch {
            logger.logError("📁 Folder export: write failed for \(request.relativePath) - \(error.localizedDescription)")
            return .writeFailed(error.localizedDescription)
        }
    }
}
