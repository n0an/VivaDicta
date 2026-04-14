//
//  TranscriptionServiceProtocol.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import Foundation

/// A protocol defining the interface for audio transcription services.
///
/// Conforming types provide speech-to-text transcription capabilities using various
/// backends, including on-device models (WhisperKit, Parakeet) and cloud services
/// (OpenAI, Groq, Deepgram, etc.).
///
/// ## Overview
///
/// The transcription service architecture uses this protocol to abstract different
/// transcription backends, allowing the app to switch between providers seamlessly.
///
/// ## Conforming Types
///
/// - ``WhisperKitTranscriptionService``: On-device OpenAI Whisper model inference
/// - ``ParakeetTranscriptionService``: On-device NVIDIA Parakeet model transcription
/// - ``CloudTranscriptionService``: Unified service for cloud providers
protocol TranscriptionService {
    /// Transcribes audio from a file URL using the specified model.
    ///
    /// - Parameters:
    ///   - audioURL: The file URL of the audio to transcribe. Must be a valid local file URL
    ///     pointing to an audio file in a supported format (WAV, M4A, MP3).
    ///   - model: The transcription model to use. Must be compatible with the service implementation.
    ///
    /// - Returns: The transcribed text plus metadata about the result.
    ///
    /// - Throws: ``TranscriptionError`` if transcription fails, including network errors
    ///   for cloud services or model loading errors for on-device services.
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult
}
