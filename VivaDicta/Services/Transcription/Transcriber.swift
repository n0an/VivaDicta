// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import TranscriptionCore

/// A seam over `TranscriptionManager` so orchestrators (e.g. `WatchAudioProcessor`)
/// depend on the *behavior* - "turn audio into text under the current mode" -
/// rather than the concrete manager.
///
/// `TranscriptionManager.transcribe()` resolves a real, downloaded/keyed model
/// *before* its injectable `engine` seam, which makes the full transcribe step
/// untestable through the engine alone. Depending on this protocol lets a test
/// substitute a deterministic `MockTranscriber` and drive the whole
/// record → transcribe → enhance → store flow.
@MainActor
protocol Transcriber {
    /// The mode currently driving transcription (provider, model, language).
    var currentMode: VivaMode { get }

    /// Switch the active mode.
    func setCurrentMode(_ mode: VivaMode)

    /// The resolved model for the current mode, or `nil` when unavailable
    /// (not downloaded / no API key).
    func getCurrentTranscriptionModel() -> (any TranscriptionModel)?

    /// Transcribe `audioURL` under the current mode, apply the post-processing
    /// pipeline, and return the final text plus backend metadata (e.g.
    /// language-identification scores from local WhisperKit).
    func transcribe(audioURL: URL, progressHandler: TranscriptionProgressHandler?) async throws -> TranscriptionServiceResult
}
