//
//  WhisperModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation

enum TranscriptionModel: Hashable {
    case local
    case cloud
}

enum CloudTranscriptionModel: String, CaseIterable, Identifiable {
    var id: Self { self }
    case openAI
    case elevenlabs
    case groq
}   

enum WhisperModelEnum: String, Hashable, CaseIterable, Identifiable {
    var id: Self { self }
    
    case tiny = "ggml-tiny"
    case tiny_q5_1 = "ggml-tiny-q5_1"
    case tiny_q8_0 = "ggml-tiny-q8_0"
    
    case tiny_en = "ggml-tiny.en"
    case tiny_en_q5_1 = "ggml-tiny.en-q5_1"
    case tiny_en_q8_0 = "ggml-tiny.en-q8_0"
    
    case base = "ggml-base"
    case base_q5_1 = "ggml-base-q5_1"
    case base_q8_0 = "ggml-base-q8_0"
    
    case base_en = "ggml-base.en"
    case base_en_q5_1 = "ggml-base.en-q5_1"
    case base_en_q8_0 = "ggml-base.en-q8_0"
    
    case largeV3 = "ggml-large-v3"
    case largeV3_q5_0 = "ggml-large-v3-q5_0"
    
    case largeV3Turbo = "ggml-large-v3-turbo"
    case largeV3Turbo_q5_0 = "ggml-large-v3-turbo-q5_0"
    case largeV3Turbo_q8_0 = "ggml-large-v3-turbo-q8_0"
    
    static let defaultURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
    
    var filename: String {
        "\(self.rawValue).bin"
    }
    
    var downloadURL: URL? {
        URL(string: "\(Self.defaultURL)\(filename)")
    }
    
    var coreMLDownloadURL: URL? {
        // Only non-quantized models have Core ML versions
        guard !rawValue.contains("q5") && !rawValue.contains("q8") else { return nil }
        return URL(string: "\(Self.defaultURL)\(rawValue)-encoder.mlmodelc.zip")
    }
    
//    var coreMLEncoderURL: URL? // Path to the unzipped .mlmodelc directory
//    var isCoreMLDownloaded: Bool { coreMLEncoderURL != nil }
    
    var coreMLEncoderDirectoryName: String? {
        guard coreMLDownloadURL != nil else { return nil }
        return "\(rawValue)-encoder.mlmodelc"
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




//struct WhisperModel: Identifiable {
//    let id = UUID()
//    let name: String
//    let url: URL
//    var coreMLEncoderURL: URL? // Path to the unzipped .mlmodelc directory
//    var isCoreMLDownloaded: Bool { coreMLEncoderURL != nil }
//    
//    var downloadURL: String {
//        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)"
//    }
//    
//    var filename: String {
//        "\(name).bin"
//    }
//    
//    // Core ML related properties
//    var coreMLZipDownloadURL: String? {
//        // Only non-quantized models have Core ML versions
//        guard !name.contains("q5") && !name.contains("q8") else { return nil }
//        return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(name)-encoder.mlmodelc.zip"
//    }
//    
//    var coreMLEncoderDirectoryName: String? {
//        guard coreMLZipDownloadURL != nil else { return nil }
//        return "\(name)-encoder.mlmodelc"
//    }
//}
