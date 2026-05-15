// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

public enum TranscriptionError: LocalizedError {
    case modelLoadFailed
    case transcriptionFailed
    case unsupportedModel
    case audioConversionFailed
    case modelNotDownloaded

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load transcription model"
        case .transcriptionFailed:
            return "Transcription failed"
        case .unsupportedModel:
            return "Unsupported model type"
        case .audioConversionFailed:
            return "Failed to convert audio format"
        case .modelNotDownloaded:
            return "Model not downloaded"
        }
    }

    public var failureReason: String {
        switch self {
        case .modelLoadFailed:
            return "The transcription model could not be loaded. Please try downloading the model again."
        case .transcriptionFailed:
            return "The audio could not be transcribed. Please try again or use a different model."
        case .unsupportedModel:
            return "This model type is not supported for transcription."
        case .audioConversionFailed:
            return "The audio file could not be converted to the required format."
        case .modelNotDownloaded:
            return "The selected model has not been downloaded yet. Please download it first."
        }
    }
}
