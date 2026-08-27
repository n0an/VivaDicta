//
//  RealtimeDictationCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.08
//

import AICore
import AppGroup
import Foundation
import Keychain
import os

/// Pairs `StreamingAudioCapture` with a `RealtimeDictationSession` for one
/// dictation, so `RecordViewModel` deals with a single object rather than an
/// engine, a socket, and the pump task between them.
///
/// Which session runs is decided by the selected model, and the capture side
/// does not vary with it - every backend is fed the same PCM.
///
/// The recorded WAV is still written throughout. If the socket fails at any
/// point the caller can simply transcribe that file the normal way, which is
/// why `finish()` throws instead of returning a partial transcript.
@MainActor
final class RealtimeDictationCoordinator {
    private let logger = Logger(category: .sonioxRealtimeDictation)
    private let capture = StreamingAudioCapture()
    private let keychain: any KeychainService
    private var session: (any RealtimeDictationSession)?

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
        guard let key = apiKey(for: modelName, keychain: keychain), !key.isEmpty else { return false }

        let translationTarget = mode.translationTargetLanguage ?? ""
        guard translationTarget.isEmpty else { return false }

        // Speaker labels are a global setting rather than a mode property.
        guard !AppGroupCoordinator.shared.isSpeakerDiarizationEnabled else { return false }

        return true
    }

    /// Starts capture and opens the socket. Throws only if *capture* fails -
    /// a socket that never connects surfaces later, at `finish()`, by which
    /// point the WAV is complete and the fallback can take over.
    func start(writingTo url: URL, modelName: String, transcriptionLanguage: String) async throws {
        guard !isActive else { return }

        guard let apiKey = Self.apiKey(for: modelName, keychain: keychain), !apiKey.isEmpty else {
            throw RealtimeDictationSessionError.transportFailed("missing API key for \(modelName)")
        }

        let session = Self.makeSession(for: modelName)
        self.session = session

        let stream = capture.makeStream()
        try await capture.start(writingTo: url)
        isActive = true

        // "auto" means let the provider detect; sending it as a hint would be wrong.
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

    /// The backend that serves this model's realtime socket.
    private static func makeSession(for modelName: String) -> any RealtimeDictationSession {
        if TranscriptionModelProvider.isDeepgramFluxModel(modelName) {
            return DeepgramFluxRealtimeSession(modelName: modelName)
        }
        if TranscriptionModelProvider.deepgramNovaRealtimeModels.contains(modelName) {
            return DeepgramNovaRealtimeSession(modelName: modelName)
        }
        if modelName == TranscriptionModelProvider.elevenLabsRealtimeModel {
            return ElevenLabsRealtimeSession()
        }
        if modelName == TranscriptionModelProvider.mistralRealtimeModel {
            return MistralRealtimeSession()
        }
        return SonioxRealtimeDictationSession()
    }

    /// Realtime models come from several providers with separate keys, so the key
    /// is resolved from the model rather than assumed to be Soniox's.
    private static func apiKey(for modelName: String, keychain: any KeychainService) -> String? {
        if TranscriptionModelProvider.isDeepgramFluxModel(modelName)
            || TranscriptionModelProvider.deepgramNovaRealtimeModels.contains(modelName) {
            return AIProvider.deepgram.apiKey
        }
        if modelName == TranscriptionModelProvider.elevenLabsRealtimeModel {
            return AIProvider.elevenLabs.apiKey
        }
        if modelName == TranscriptionModelProvider.mistralRealtimeModel {
            return AIProvider.mistral.apiKey
        }
        return keychain.getString(forKey: "sonioxAPIKey")
    }

    /// Stops capture, flushes the socket, and returns the transcript.
    /// Throws when realtime produced nothing usable, signalling the caller to
    /// fall back to uploading the recorded file.
    func finish() async throws -> String {
        // Tear down before deciding whether there is anything to return. A stop
        // can land while `start()` is still suspended, and bailing out early
        // there would strand a running engine and socket behind a UI that has
        // already moved on.
        let wasActive = isActive
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

        guard let session else { throw RealtimeDictationSessionError.producedNoText }

        guard wasActive else {
            await session.cancel()
            throw RealtimeDictationSessionError.producedNoText
        }

        return try await session.finish()
    }

    func cancel() async {
        isActive = false
        await capture.stop()
        pumpTask?.cancel()
        pumpTask = nil
        await session?.cancel()
        session = nil
    }
}
