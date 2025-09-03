//
//  WhisperModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation

//enum TranscriptionModel: Hashable {
//    case local
//    case cloud
//}
//
//enum CloudTranscriptionModel: String, CaseIterable, Identifiable {
//    var id: Self { self }
//    case openAI
//    case elevenlabs
//    case groq
//}





//enum WhisperModel: String, Hashable, CaseIterable, Identifiable {
//    var id: Self { self }
//    static let defaultURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
//    
//    var filename: String {
//        "\(self.rawValue).bin"
//    }
//    
//    var downloadURL: URL? {
//        URL(string: "\(Self.defaultURL)\(filename)")
//    }
//    
//    var coreMLDownloadURL: URL? {
//        // Only non-quantized models have Core ML versions
//        guard !rawValue.contains("q5") && !rawValue.contains("q8") else { return nil }
//        return URL(string: "\(Self.defaultURL)\(rawValue)-encoder.mlmodelc.zip")
//    }
//    
//    var coreMLEncoderDirectoryName: String? {
//        guard coreMLDownloadURL != nil else { return nil }
//        return "\(rawValue)-encoder.mlmodelc"
//    }
//    
//    var fileURL: URL {
//        URL.documentsDirectory.appendingPathComponent(filename)
//    }
//    
//    var fileExists: Bool {
//        FileManager.default.fileExists(atPath: fileURL.path)
//    }
//    
//    
//    static var downloadedModels: [WhisperModel] {
//        return WhisperModel.allCases.filter { $0.fileExists }
//    }
//}
