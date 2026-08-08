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

    /// Emits the best-known transcript (finals + current interim) as it grows,
    /// so callers can show live text while the user is still speaking.
    private var previewContinuation: AsyncStream<String>.Continuation?
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

    func makePreviewStream() -> AsyncStream<String> {
        AsyncStream<String> { continuation in
            previewContinuation = continuation
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
            try? await Task.sleep(for: .milliseconds(50))
        }

        await teardown()

        if let failureMessage {
            throw SessionError.transportFailed(failureMessage)
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
        previewContinuation?.yield(accumulator.text)
    }

    private func markStreamEnded() {
        didFinish = true
    }

    private func teardown() async {
        isRunning = false
        receiveTask?.cancel()
        receiveTask = nil
        previewContinuation?.finish()
        previewContinuation = nil
        await client.disconnect()
    }
}
