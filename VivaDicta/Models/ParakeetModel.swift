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
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double

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
    
    var modelsDirectory: URL {
        switch version {
        case .v2:
            FileManager.appDirectory(for: .parakeetModels).appendingPathComponent("parakeet-tdt-0.6b-v2-coreml")
        case .v3:
            FileManager.appDirectory(for: .parakeetModels).appendingPathComponent("parakeet-tdt-0.6b-v3-coreml")
        }
        
    }
    
    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: modelsDirectory.path)
    }
}

