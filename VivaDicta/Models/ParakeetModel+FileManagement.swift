//
//  ParakeetModel+FileManagement.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.16
//

import Foundation
import LocalTranscription
import TranscriptionCore

// This extension lives in a main-target-only file because it depends on the
// LocalTranscription package, which the extension targets do not link.
// `ParakeetModel` itself is shared with extensions via folder-sync; this file
// is not part of those extensions' folder-sync (the file is new and Xcode adds
// new app-target files to the main target only).
extension ParakeetModel {
    var version: ParakeetModelVersion {
        name.lowercased().contains("v2") ? .v2 : .v3
    }

    var modelsDirectory: URL {
        ParakeetModelPath.directory(for: version)
    }

    private var hasCachedModelDirectory: Bool {
        FileManager.default.fileExists(atPath: modelsDirectory.path)
    }

    var isDownloaded: Bool {
        ParakeetModelPath.isDownloaded(version: version)
    }

    func deleteModel() throws {
        if hasCachedModelDirectory {
            try FileManager.default.removeItem(at: modelsDirectory)
        }
    }
}
