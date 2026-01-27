//
//  ParakeetModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.27
//

import Foundation
import FluidAudio

struct ParakeetModel: @MainActor TranscriptionModel, Equatable {
    static func == (lhs: ParakeetModel, rhs: ParakeetModel) -> Bool {
        lhs.id == rhs.id
    }
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: TranscriptionModelProvider = .parakeet
    let recommended: Bool
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    init(name: String,
         displayName: String,
         description: String,
         recommended: Bool = false,
         size: String,
         speed: Double,
         accuracy: Double,
         ramUsage: Double,
         supportedLanguages: [String : String]) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.recommended = recommended
        self.size = size
        self.speed = speed
        self.accuracy = accuracy
        self.ramUsage = ramUsage
        self.supportedLanguages = supportedLanguages
    }

    var supportManyLanguages: Bool {
        supportedLanguages.count > 1
    }

    let supportedLanguages: [String: String]
}

// MARK: - Download & File Management
extension ParakeetModel {
    var version: AsrModelVersion {
        name.lowercased().contains("v2") ? .v2 : .v3
    }

    /// Returns FluidAudio's default cache directory for this model version.
    /// This ensures consistency between download, validation, and loading.
    var modelsDirectory: URL {
        AsrModels.defaultCacheDirectory(for: version)
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

