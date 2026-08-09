//
//  SonioxRealtimeDictationSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.08
//

import Foundation
import os

/// Drives one dictation over Soniox's realtime WebSocket.
///
/// The async REST path can only start work once the user stops talking (upload
/// → create job → poll). This streams PCM while they speak, so by the time
/// `finish()` is called the server has usually emitted every final token
/// already and only the tail is outstanding.
///
/// Soniox sends non-final tokens as a *full replacement set* for the current
/// interim region, so this keeps finals and interims apart and rebuilds the
/// preview text on every batch rather than appending blindly.
actor SonioxRealtimeDictationSession {
    enum SessionError: LocalizedError {
        case transportFailed(String)
        case producedNoText

        var errorDescription: String? {
            switch self {
            case .transportFailed(let message): "Realtime transcription failed: \(message)"
            case .producedNoText: "Realtime transcription returned no text"
            }
        }
    }

    /// How long `finish()` waits for the server to flush remaining tokens after
    /// the end-of-audio marker. Streaming has already delivered the bulk of the
    /// transcript by then, so this is a tail-latency guard, not the main wait.
    private static let finalizeTimeout: Duration = .seconds(10)

    private let logger = Logger(category: .sonioxRealtimeDictation)
    private let client = SonioxRealtimeSTTClient()

    private var accumulator = RealtimeTranscriptAccumulator()
    private var isRunning = false
    private var failureMessage: String?
    private var didFinish = false

    private var receiveTask: Task<Void, Never>?

    /// Text captured so far. Safe to read at any point.
    var currentText: String {
        accumulator.text
    }

    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async {
        guard !isRunning else { return }
        isRunning = true

        let stream = await client.connect(
            apiKey: apiKey,
            languageHints: languageHints,
            mode: .transcription,
            vocabularyTerms: vocabularyTerms
        )

        receiveTask = Task { [weak self] in
            for await event in stream {
                await self?.handle(event)
            }
            await self?.markStreamEnded()
        }
    }

    func send(_ pcmChunk: Data) async {
        guard isRunning, failureMessage == nil else { return }
        await client.sendAudioChunk(pcmChunk)
    }

    /// Signals end-of-audio and waits for the server's remaining tokens.
    ///
    /// Throws rather than returning partial text on transport failure so the
    /// caller can fall back to uploading the recorded file - the file is
    /// written in parallel precisely so that fallback stays available.
    func finish() async throws -> String {
        guard isRunning else { throw SessionError.producedNoText }

        await client.finalizeAudio()

        let deadline = ContinuousClock.now.advanced(by: Self.finalizeTimeout)
        while !didFinish, failureMessage == nil, ContinuousClock.now < deadline {
            // On a cancelled task `Task.sleep` throws immediately and `try?`
            // swallows it, so without this the loop spins at full speed until
            // the deadline. Breaking lands in the timeout path below, which
            // throws - the right outcome for a cancel.
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let didTimeOut = !didFinish && failureMessage == nil

        await teardown()

        if let failureMessage {
            throw SessionError.transportFailed(failureMessage)
        }

        // A timeout means the server never confirmed it was done, so whatever
        // accumulated may be missing the tail and can still contain an
        // unsettled interim region. Returning it would silently save a
        // truncated transcript, so treat it as a transport failure and let the
        // caller upload the recorded file instead.
        if didTimeOut {
            logger.logWarning("Realtime finalize timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for final tokens")
        }

        let text = accumulator.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SessionError.producedNoText }
        return text
    }

    /// Aborts without waiting - used when the user cancels the recording.
    func cancel() async {
        await teardown()
    }

    // MARK: - Private

    private func handle(_ event: SonioxRealtimeSTTClient.Event) {
        switch event {
        case .tokens(let batch):
            apply(batch)
        case .finished:
            didFinish = true
        case .failed(let message):
            logger.logError("Realtime dictation failed: \(message)")
            failureMessage = message
        }
    }

    private func apply(_ batch: [LiveTranslationToken]) {
        accumulator.ingest(batch)
    }

    private func markStreamEnded() {
        didFinish = true
    }

    private func teardown() async {
        isRunning = false
        receiveTask?.cancel()
        receiveTask = nil
        await client.disconnect()
    }
}
