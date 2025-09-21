//
//  WhisperError.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.01
//

import Foundation

enum WhisperStateError: LocalizedError {
    case modelLoadFailed
    case transcriptionFailed
    case whisperCoreFailed
    case unzipFailed
    case unknownError
        
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load the transcription model."
        case .transcriptionFailed:
            return "Failed to transcribe the audio."
        case .whisperCoreFailed:
            return "The core transcription engine failed."
        case .unzipFailed:
            return "Failed to unzip the downloaded Core ML model."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}
