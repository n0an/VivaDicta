//
//  RecordingState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 25.11.2025.
//

import Foundation

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case enhancing
    case error(RecordError)
}

enum RecordError: LocalizedError, Equatable {
    case avInitError
    case userDenied
    case recordError
    case transcribe
    case aiGuardrail
    case aiRefusal(String)
    case aiEnhancement(String)
    case other
    case debugError

    var errorDescription: String? {
        switch self {
        case .avInitError:
            "Audio initialization failed"
        case .userDenied:
            "Microphone access denied"
        case .recordError:
            "Recording failed"
        case .transcribe:
            "Transcription failed"
        case .aiGuardrail:
            "AI Safety Guardrail Triggered"
        case .aiRefusal:
            "AI Declined to Respond"
        case .aiEnhancement:
            "AI Processing Failed"
        case .other:
            "Unexpected error"
        case .debugError:
            "DEBUG ERROR"
        }
    }

    var failureReason: String {
        switch self {
        case .avInitError:
            return "Failed to initialize audio recording system. Please restart the app and try again."
        case .userDenied:
            return "Microphone access is required for recording. Please go to Settings > Privacy & Security > Microphone and enable access for VivaDicta."
        case .recordError:
            return "Failed to record audio. Check that no other app is using the microphone and try again."
        case .transcribe:
            return "Failed to transcribe the recorded audio. Please check your transcription settings and try again."
        case .aiGuardrail:
            return "Apple's on-device AI blocked this content due to safety guidelines. Your transcription was saved without AI processing. Consider using a cloud AI provider for this type of content."
        case .aiRefusal(let reason):
            return "Apple's on-device AI declined to process this content: \(reason). Your transcription was saved without AI processing."
        case .aiEnhancement(let message):
            return "AI processing failed: \(message). Your transcription was saved without enhancement."
        case .other:
            return "An unexpected error occurred. Please restart the app and try again."
        case .debugError:
            return "DEBUG ERROR"
        }
    }
}
