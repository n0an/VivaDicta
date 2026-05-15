//
//  WhisperKitModel+FileManagement.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import LocalTranscription

// This extension lives in a main-target-only file because it depends on the
// LocalTranscription package, which the extension targets do not link.
// `WhisperKitModel` itself is shared with extensions via folder-sync; this
// file is excluded from their membershipExceptions.
extension WhisperKitModel {
    /// Root directory under Documents where WhisperKit models are downloaded.
    public static var whisperKitModelsRoot: URL {
        WhisperKitModelPath.root
    }

    var modelsDirectory: URL {
        WhisperKitModelPath.directory(forModelName: whisperKitModelName)
    }

    /// Returns the full path to the WhisperKit model directory for a given model name.
    public static func modelPath(for modelName: String) -> URL {
        WhisperKitModelPath.directory(forModelName: modelName)
    }

    var isDownloaded: Bool {
        WhisperKitModelPath.isDownloaded(modelName: whisperKitModelName)
    }

    func deleteModel() throws {
        if isDownloaded {
            try FileManager.default.removeItem(at: modelsDirectory)
        }
    }
}
