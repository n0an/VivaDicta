//
//  WhisperModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation

enum TranscriptionProvider {
    case localWhisper(WhisperModelEnum)
    case openAI
}

enum WhisperModelEnum: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    
    case tiny
    case tiny_q5_1 = "tiny-q5_1"
    case tiny_q8_0 = "tiny-q8_0"
    
    case tiny_en = "tiny.en"
    case tiny_en_q5_1 = "tiny.en-q5_1"
    case tiny_en_q8_0 = "tiny.en-q8_0"
    
    case base = "base"
    case base_q5_1 = "base-q5_1"
    case base_q8_0 = "base-q8_0"
    
    case base_en = "base.en"
    case base_en_q5_1 = "base.en-q5_1"
    case base_en_q8_0 = "base.en-q8_0"
    
    case small = "small"
    case small_q5_1 = "small-q5_1"
    case small_q8_0 = "small-q8_0"
    
    case small_en = "small.en"
    case small_en_q5_1 = "small.en-q5_1"
    case small_en_q8_0 = "small.en-q8_0"
    
    case medium = "medium"
    case medium_q5_0 = "medium-q5_0"
    case medium_q8_0 = "medium-q8_0"
    
    case medium_en = "medium.en"
    case medium_en_q5_0 = "medium.en-q5_0"
    case medium_en_q8_0 = "medium.en-q8_0"
    
    case largeV2 = "large-v2"
    case largeV2_q5_0 = "large-v2-q5_0"
    case largeV2_q8_0 = "large-v2-q8_0"
    
    case largeV3 = "large-v3"
    case largeV3_q5_0 = "large-v3-q5_0"
    
    case largeV3Turbo = "large-v3-turbo"
    case largeV3Turbo_q5_0 = "large-v3-turbo-q5_0"
    case largeV3Turbo_q8_0 = "large-v3-turbo-q8_0"
    
    static let defaultURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
    
    var filename: String {
        "\(self.rawValue).bin"
    }
    
    var downloadURL: URL? {
        URL(string: "\(Self.defaultURL)ggml-\(filename)")
    }
    
    var fileURL: URL {
        URL.documentsDirectory.appendingPathComponent(filename)
    }
    
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    var info: String {
        switch self {
        case .tiny:
            "(F16, 75 MiB)"
        case .tiny_q5_1:
            "(31 MiB)"
        case .tiny_q8_0:
            "(42 MiB)"
        case .tiny_en:
            "(F16, 75 MiB)"
        case .tiny_en_q5_1:
            "(31 MiB)"
        case .tiny_en_q8_0:
            "(42 MiB)"
        case .base:
            "(F16, 142 MiB)"
        case .base_q5_1:
            "(57 MiB)"
        case .base_q8_0:
            "(78 MiB)"
        case .base_en:
            "(F16, 142 MiB)"
        case .base_en_q5_1:
            "(57 MiB)"
        case .base_en_q8_0:
            "(78 MiB)"
        case .small:
            "(F16, 466 MiB)"
        case .small_q5_1:
            "(181 MiB)"
        case .small_q8_0:
            "(252 MiB)"
        case .small_en:
            "(F16, 466 MiB)"
        case .small_en_q5_1:
            "(181 MiB)"
        case .small_en_q8_0:
            "(252 MiB)"
        case .medium:
            "(F16, 1.5 GiB)"
        case .medium_q5_0:
            "(514 MiB)"
        case .medium_q8_0:
            "(785 MiB)"
        case .medium_en:
            "(F16, 1.5 GiB)"
        case .medium_en_q5_0:
            "(514 MiB)"
        case .medium_en_q8_0:
            "(785 MiB)"
        case .largeV2:
            "(F16, 2.9 GiB)"
        case .largeV2_q5_0:
            "(1.1 GiB)"
        case .largeV2_q8_0:
            "(1.5 GiB)"
        case .largeV3:
            "(F16, 2.9 GiB)"
        case .largeV3_q5_0:
            "(1.1 GiB)"
        case .largeV3Turbo:
            "(F16, 1.5 GiB)"
        case .largeV3Turbo_q5_0:
            "(547 MiB)"
        case .largeV3Turbo_q8_0:
            "(834 MiB)"
        }
    }
    
    static var downloadedModels: [WhisperModelEnum] {
        return WhisperModelEnum.allCases.filter {
            FileManager.default.fileExists(atPath: $0.fileURL.path())
        }
    }
}

