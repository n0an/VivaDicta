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
    /// A call, alarm, or Siri took the microphone mid-recording. Not a failure:
    /// whatever was captured before it is saved and transcribed as usual.
    case interrupted
    /// Transcription threw. The associated value is the underlying reason,
    /// surfaced to the user the way ``aiEnhancement`` surfaces its own.
    case transcribe(String)
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
        case .interrupted:
            "Recording Interrupted"
        case .transcribe:
            "Transcription Failed"
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
            return "Failed to start recording. Check that no other app is using the microphone and try again."
        case .interrupted:
            return "Something else needed the microphone, so recording stopped early. The audio captured up to that point was saved and transcribed."
        case .transcribe(let reason):
            return "Failed to transcribe the recording: \(reason). The recording was saved - open it from the notes list to play it back or retry."
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
