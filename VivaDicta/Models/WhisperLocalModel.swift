//
//  WhisperLocalModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

struct WhisperLocalModel: TranscriptionModel, Identifiable {
    var id: UUID = .init()
    var name: String
    var displayName: String
    var description: String
    var provider: TranscriptionModelProvider = .local
    
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    var supportManyLanguages: Bool {
        supportedLanguages.count > 1
    }
    
    var supportedLanguages: [String: String]
}

// MARK: - Download
extension WhisperLocalModel {
    static let defaultURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"

    var filename: String {
        "\(self.name).bin"
    }
    
    var downloadURL: URL? {
        URL(string: "\(Self.defaultURL)\(filename)")
    }
    
    var coreMLDownloadURL: URL? {
        // Only non-quantized models have Core ML versions
        guard !name.contains("q5") && !name.contains("q8") else { return nil }
        return URL(string: "\(Self.defaultURL)\(name)-encoder.mlmodelc.zip")
    }
    
    var fileURL: URL {
        URL.documentsDirectory.appendingPathComponent(filename)
    }
    
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}

extension WhisperLocalModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WhisperLocalModel, rhs: WhisperLocalModel) -> Bool {
        lhs.id == rhs.id
    }
}
