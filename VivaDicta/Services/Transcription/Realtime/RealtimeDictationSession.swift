//
//  RealtimeDictationSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.27
//

import Foundation

/// Failure modes shared by every realtime dictation backend.
///
/// Both cases mean the same thing to the caller: stop waiting on the socket and
/// upload the WAV that was being written alongside it.
enum RealtimeDictationSessionError: LocalizedError {
    case transportFailed(String)
    case producedNoText

    var errorDescription: String? {
        switch self {
        case .transportFailed(let message): "Realtime transcription failed: \(message)"
        case .producedNoText: "Realtime transcription returned no text"
        }
    }
}

/// One dictation carried over a provider's realtime socket.
///
/// `RealtimeDictationCoordinator` pairs whichever conformer matches the selected
/// model with the one `StreamingAudioCapture`, so the capture side stays
/// provider-agnostic: every conformer is fed the same PCM (`pcm_s16le`, 16 kHz,
/// mono) that `StreamingAudioCapture` already produces.
///
/// `finish()` throws rather than returning partial text, because the caller's
/// recovery is to transcribe the recorded file instead - a truncated transcript
/// returned as a success would be saved silently.
protocol RealtimeDictationSession: Actor {
    /// Opens the socket. Non-throwing: a socket that never connects surfaces at
    /// `finish()`, by which point the WAV is complete and the fallback can run.
    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async

    func send(_ pcmChunk: Data) async

    /// Signals end-of-audio and waits for the server's remaining text.
    func finish() async throws -> String

    /// Aborts without waiting - used when the user cancels the recording.
    func cancel() async
}
