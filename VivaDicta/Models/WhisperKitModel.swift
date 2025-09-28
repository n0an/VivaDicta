//
//  WhisperKitModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import Foundation

struct WhisperKitModel: @MainActor TranscriptionModel, Equatable {
    static func == (lhs: WhisperKitModel, rhs: WhisperKitModel) -> Bool {
        lhs.id == rhs.id
    }

    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: TranscriptionModelProvider = .whisperKit
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    var supportManyLanguages: Bool {
        supportedLanguages.count > 1
    }
    
    let supportedLanguages: [String: String]

    // WhisperKit specific model identifier
    let whisperKitModelName: String
}

// MARK: - Download & File Management
extension WhisperKitModel {
    // WhisperKit downloads models to its own managed location
    private var whisperKitModelsRoot: URL {
        // WhisperKit uses ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
        let documentsPath = URL.documentsDirectory
        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
    }

    var modelsDirectory: URL {
        whisperKitModelsRoot.appendingPathComponent(whisperKitModelName)
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: modelsDirectory.path)
    }

    func deleteModel() throws {
        if isDownloaded {
            try FileManager.default.removeItem(at: modelsDirectory)
        }
    }
}
