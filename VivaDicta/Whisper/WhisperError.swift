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
            return "Failed to load the transcription model"
        case .transcriptionFailed:
            return "Failed to transcribe the audio"
        case .whisperCoreFailed:
            return "Core transcription engine failed"
        case .unzipFailed:
            return "Failed to unzip the downloaded model"
        case .unknownError:
            return "An unknown error occurred"
        }
    }

    var failureReason: String {
        switch self {
        case .modelLoadFailed:
            return "The Whisper model could not be loaded into memory. The model file may be corrupted or incompatible with the current version."
        case .transcriptionFailed:
            return "Audio transcription failed. The audio file may be corrupted, in an unsupported format, or too short to process."
        case .whisperCoreFailed:
            return "The Whisper transcription engine encountered an internal error. Please try restarting the app or reinstalling the model."
        case .unzipFailed:
            return "Could not extract the downloaded Core ML model. The download may be incomplete or the file may be corrupted."
        case .unknownError:
            return "An unexpected error occurred during transcription. Please try again or contact support if the issue persists."
        }
    }
}
