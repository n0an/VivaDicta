//
//  WhisperModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation

enum WhisperModelEnum: String {
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
    
}

struct WhisperModel: Identifiable {
    var id = UUID()
    var name: String
    var info: String
    var url: String

    var filename: String
    var fileURL: URL {
        URL.documentsDirectory.appendingPathComponent(filename)
    }
    
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    static var downloadedModels: [WhisperModel] {
        return WhisperModel.models.filter {
            FileManager.default.fileExists(atPath: $0.fileURL.path())
        }
    }
    
    static let models: [WhisperModel] = [
        WhisperModel(name: "tiny", info: "(F16, 75 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin", filename: "tiny.bin"),
        WhisperModel(name: "tiny-q5_1", info: "(31 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin", filename: "tiny-q5_1.bin"),
        WhisperModel(name: "tiny-q8_0", info: "(42 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q8_0.bin", filename: "tiny-q8_0.bin"),
        WhisperModel(name: "tiny.en", info: "(F16, 75 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin", filename: "tiny.en.bin"),
        WhisperModel(name: "tiny.en-q5_1", info: "(31 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin", filename: "tiny.en-q5_1.bin"),
        WhisperModel(name: "tiny.en-q8_0", info: "(42 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q8_0.bin", filename: "tiny.en-q8_0.bin"),
        WhisperModel(name: "base", info: "(F16, 142 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin", filename: "base.bin"),
        WhisperModel(name: "base-q5_1", info: "(57 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin", filename: "base-q5_1.bin"),
        WhisperModel(name: "base-q8_0", info: "(78 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q8_0.bin", filename: "base-q8_0.bin"),
        WhisperModel(name: "base.en", info: "(F16, 142 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin", filename: "base.en.bin"),
        WhisperModel(name: "base.en-q5_1", info: "(57 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin", filename: "base.en-q5_1.bin"),
        WhisperModel(name: "base.en-q8_0", info: "(78 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q8_0.bin", filename: "base.en-q8_0.bin"),
        WhisperModel(name: "small", info: "(F16, 466 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin", filename: "small.bin"),
        WhisperModel(name: "small-q5_1", info: "(181 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin", filename: "small-q5_1.bin"),
        WhisperModel(name: "small-q8_0", info: "(252 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin", filename: "small-q8_0.bin"),
        WhisperModel(name: "small.en", info: "(F16, 466 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin", filename: "small.en.bin"),
        WhisperModel(name: "small.en-q5_1", info: "(181 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin", filename: "small.en-q5_1.bin"),
        WhisperModel(name: "small.en-q8_0", info: "(252 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q8_0.bin", filename: "small.en-q8_0.bin"),
        WhisperModel(name: "medium", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin", filename: "medium.bin"),
        WhisperModel(name: "medium-q5_0", info: "(514 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin", filename: "medium-q5_0.bin"),
        WhisperModel(name: "medium-q8_0", info: "(785 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin", filename: "medium-q8_0.bin"),
        WhisperModel(name: "medium.en", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin", filename: "medium.en.bin"),
        WhisperModel(name: "medium.en-q5_0", info: "(514 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q5_0.bin", filename: "medium.en-q5_0.bin"),
        WhisperModel(name: "medium.en-q8_0", info: "(785 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q8_0.bin", filename: "medium.en-q8_0.bin"),
//        WhisperModel(name: "large-v1", info: "(F16, 2.9 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin", filename: "large.bin"),
        WhisperModel(name: "large-v2", info: "(F16, 2.9 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin", filename: "large-v2.bin"),
        WhisperModel(name: "large-v2-q5_0", info: "(1.1 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q5_0.bin", filename: "large-v2-q5_0.bin"),
        WhisperModel(name: "large-v2-q8_0", info: "(1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q8_0.bin", filename: "large-v2-q8_0.bin"),
        WhisperModel(name: "large-v3", info: "(F16, 2.9 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin", filename: "large-v3.bin"),
        WhisperModel(name: "large-v3-q5_0", info: "(1.1 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin", filename: "large-v3-q5_0.bin"),
        WhisperModel(name: "large-v3-turbo", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin", filename: "large-v3-turbo.bin"),
        WhisperModel(name: "large-v3-turbo-q5_0", info: "(547 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin", filename: "large-v3-turbo-q5_0.bin"),
        WhisperModel(name: "large-v3-turbo-q8_0", info: "(834 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin", filename: "large-v3-turbo-q8_0.bin"),
    ]
    
    
    
}
