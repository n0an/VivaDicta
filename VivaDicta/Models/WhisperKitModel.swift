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
    let recommended: Bool
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    init(name: String,
         displayName: String,
         description: String,
         recommended: Bool = false,
         size: String, speed: Double,
         accuracy: Double,
         ramUsage: Double,
         supportedLanguages: [String : String],
         whisperKitModelName: String) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.recommended = recommended
        self.size = size
        self.speed = speed
        self.accuracy = accuracy
        self.ramUsage = ramUsage
        self.supportedLanguages = supportedLanguages
        self.whisperKitModelName = whisperKitModelName
    }
    
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
    // WhisperKit uses ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
    public static var whisperKitModelsRoot: URL {
        URL.documentsDirectory
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
    }

    var modelsDirectory: URL {
        Self.whisperKitModelsRoot.appendingPathComponent(whisperKitModelName)
    }

    /// Returns the full path to the WhisperKit model directory for a given model name
    public static func modelPath(for modelName: String) -> URL {
        whisperKitModelsRoot.appendingPathComponent(modelName)
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
