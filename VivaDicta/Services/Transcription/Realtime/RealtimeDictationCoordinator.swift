//
//  RealtimeDictationCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.08
//

import AppGroup
import Foundation
import Keychain
import os

/// Pairs `StreamingAudioCapture` with `SonioxRealtimeDictationSession` for one
/// dictation, so `RecordViewModel` deals with a single object rather than an
/// engine, a socket, and the pump task between them.
///
/// The recorded WAV is still written throughout. If the socket fails at any
/// point the caller can simply transcribe that file the normal way, which is
/// why `finish()` throws instead of returning a partial transcript.
@MainActor
final class RealtimeDictationCoordinator {
    private let logger = Logger(category: .sonioxRealtimeDictation)
    private let capture = StreamingAudioCapture()
    private let session = SonioxRealtimeDictationSession()
    private let keychain: any KeychainService

    private var pumpTask: Task<Void, Never>?
    private(set) var isActive = false

    /// Mic level for the waveform while streaming, standing in for
    /// `AudioRecordingService.currentAudioPower` on this path.
    var currentAudioLevel: Double {
        Double(capture.currentAudioLevel)
    }

    init(keychain: any KeychainService = DefaultKeychainService()) {
        self.keychain = keychain
    }

    /// Whether realtime should be used for this mode right now. A missing API
    /// key is not an error here - the caller just records normally and the
    /// usual missing-key error surfaces from the upload path.
    ///
    /// Modes asking for inline translation or speaker labels stay on the
    /// upload path. The socket is opened in transcription-only mode, and since
    /// a successful stream bypasses the Soniox job entirely, streaming those
    /// modes would quietly save untranslated text with no speaker attribution
    /// - a worse failure than simply being slower.
    static func canHandle(
        mode: VivaMode,
        modelName: String?,
        keychain: any KeychainService = DefaultKeychainService()
    ) -> Bool {
        guard let modelName, TranscriptionModelProvider.isStreamingModel(modelName) else { return false }
        guard let key = keychain.getString(forKey: "sonioxAPIKey"), !key.isEmpty else { return false }

        let translationTarget = mode.translationTargetLanguage ?? ""
        guard translationTarget.isEmpty else { return false }

        // Speaker labels are a global setting rather than a mode property.
        guard !AppGroupCoordinator.shared.isSpeakerDiarizationEnabled else { return false }

        return true
    }

    /// Starts capture and opens the socket. Throws only if *capture* fails -
    /// a socket that never connects surfaces later, at `finish()`, by which
    /// point the WAV is complete and the fallback can take over.
    func start(writingTo url: URL, transcriptionLanguage: String) async throws {
        guard !isActive else { return }

        guard let apiKey = keychain.getString(forKey: "sonioxAPIKey"), !apiKey.isEmpty else {
            throw SonioxRealtimeDictationSession.SessionError.transportFailed("missing Soniox API key")
        }

        let stream = capture.makeStream()
        try await capture.start(writingTo: url)
        isActive = true

        // "auto" means let Soniox detect; sending it as a hint would be wrong.
        let hints = (transcriptionLanguage == "auto" || transcriptionLanguage.isEmpty) ? [] : [transcriptionLanguage]

        await session.start(
            apiKey: apiKey,
            languageHints: hints,
            vocabularyTerms: CustomVocabulary.getTerms()
        )

        pumpTask = Task { [session] in
            for await chunk in stream {
                await session.send(chunk)
            }
        }
    }

    /// Stops capture, flushes the socket, and returns the transcript.
    /// Throws when realtime produced nothing usable, signalling the caller to
    /// fall back to uploading the recorded file.
    func finish() async throws -> String {
        guard isActive else {
            throw SonioxRealtimeDictationSession.SessionError.producedNoText
        }
        isActive = false

        // Stop the mic first so no audio arrives after the end-of-audio marker.
        await capture.stop()

        // `capture.stop()` finishes the stream, but up to ~1s of chunks may
        // still be buffered in it. Wait for the pump to drain them rather than
        // cancelling - cancelling here drops the tail of the recording, and
        // because the socket would still return a successful (just truncated)
        // transcript, nothing downstream would notice the loss.
        await pumpTask?.value
        pumpTask = nil

        return try await session.finish()
    }

    func cancel() async {
        isActive = false
        await capture.stop()
        pumpTask?.cancel()
        pumpTask = nil
        await session.cancel()
    }
}
