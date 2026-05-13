//
//  FolderExportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.03
//

import Foundation
import os

/// Silently writes each transcription as a markdown file into a user-picked
/// folder (e.g. an Obsidian vault inside iCloud Drive). The folder is selected
/// once via `UIDocumentPickerViewController` and remembered as a security-scoped
/// bookmark stored in the App Group, so the keyboard extension can write too.
///
/// Mirrors the existing Obsidian integration: gated by a global toggle plus a
/// per-mode toggle, and triggered at the same points in `RecordViewModel`.
enum FolderExportService {
    private static let logger = Logger(category: .folderExportService)

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

        let snapshots = TranscriptionMarkdownExportService.snapshots(for: [transcription])
        guard let snapshot = snapshots.first else { return }
        let items = TranscriptionMarkdownExportService.items(forSnapshots: snapshots)
        guard let item = items.first else { return }

        Task(priority: .utility) { @concurrent in
            await write(item: item, snapshot: snapshot, bookmark: bookmark)
        }
    }

    /// Outcome of a manual export attempt. Distinguishes failures so the UI
    /// can show specific guidance instead of a generic "something went wrong".
    enum ManualSaveResult: Equatable {
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

        let snapshots = TranscriptionMarkdownExportService.snapshots(for: [transcription])
        guard let snapshot = snapshots.first else { return .writeFailed("No transcription snapshot") }
        let items = TranscriptionMarkdownExportService.items(forSnapshots: snapshots)
        guard let item = items.first else { return .writeFailed("No exportable item") }

        return await Task(priority: .userInitiated) { @concurrent in
            await writeWithResult(item: item, snapshot: snapshot, bookmark: bookmark)
        }.value
    }

    private static func write(
        item: MarkdownExportItem,
        snapshot: TranscriptionMarkdownExportService.Snapshot,
        bookmark: Data
    ) async {
        _ = await writeWithResult(item: item, snapshot: snapshot, bookmark: bookmark)
    }

    /// Same as `write`, but returns a typed outcome so manual callers can
    /// surface accurate UI feedback (e.g. distinguish "bookmark stale" from
    /// "write failed").
    private static func writeWithResult(
        item: MarkdownExportItem,
        snapshot: TranscriptionMarkdownExportService.Snapshot,
        bookmark: Data
    ) async -> ManualSaveResult {
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

        let destination = uniqueDestination(in: folderURL, baseFilename: item.filename)
        do {
            try Data(item.text.utf8).write(to: destination, options: .atomic)
            logger.logInfo("📁 Folder export: wrote \(destination.lastPathComponent)")
            return .success(filename: destination.lastPathComponent)
        } catch {
            logger.logError("📁 Folder export: write failed for \(destination.lastPathComponent) - \(error.localizedDescription)")
            return .writeFailed(error.localizedDescription)
        }
    }

    /// Picks a non-conflicting filename inside `folder`. The base filename
    /// from `TranscriptionMarkdownExportService` is already unique-per-second,
    /// but if a file with the same name exists (e.g. duplicate save) we
    /// append `-2`, `-3`, etc.
    private static func uniqueDestination(in folder: URL, baseFilename: String) -> URL {
        let initial = folder.appending(path: baseFilename, directoryHint: .notDirectory)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }

        let pathExtension = (baseFilename as NSString).pathExtension
        let baseStem = (baseFilename as NSString).deletingPathExtension
        var index = 2
        while index < 1_000 {
            let candidateName = pathExtension.isEmpty
                ? "\(baseStem)-\(index)"
                : "\(baseStem)-\(index).\(pathExtension)"
            let candidate = folder.appending(path: candidateName, directoryHint: .notDirectory)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
        return initial
    }
}
