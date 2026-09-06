//
//  GeminiLiveRealtimeSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.09.06
//

import Foundation
import os

/// Drives one dictation over Gemini's Live API (`BidiGenerateContent`).
///
/// Realtime-only: `gemini-3.5-transcribe-live` is served solely by the Live
/// socket. The Interactions API that `gemini-3.5-transcribe` speaks does not
/// accept it, so a selection that reaches the upload path transcribes as
/// `gemini-3.5-transcribe` instead - which is what
/// `TranscriptionModelProvider.asyncEquivalent(of:)` maps it to.
///
/// The protocol is interim/final over two separate fields:
/// `interimInputTranscription` is the frequently-rewritten unsettled tail, and
/// `inputTranscription` is an utterance that has settled. Settled utterances
/// accumulate; the interim is replaced, and cleared whenever an utterance
/// settles so its tail is not counted twice.
///
/// **End-of-stream is the soft spot.** Google documents `audioStreamEnd` as the
/// way to signal that the audio has stopped, but does not document what a
/// transcription-only session sends back once it has drained - there is no
/// documented terminator equivalent to Deepgram's `Metadata` or Cartesia's
/// `done`. So `finish()` accepts three endings: an explicit `turnComplete` /
/// `generationComplete`, or - failing that - a quiet window with settled text
/// already in hand. Waiting only for an explicit terminator that may never
/// arrive would make every dictation pay the full timeout and then fall back to
/// the upload path, which is slower than not streaming at all.
///
/// Live sessions are capped at 10 minutes server-side. Dictation is far shorter,
/// and a session that outlives the cap surfaces as a transport failure, which
/// already falls back to uploading the recorded WAV.
actor GeminiLiveRealtimeSession: RealtimeDictationSession {
    typealias SessionError = RealtimeDictationSessionError

    /// The Live model this socket runs. Sent in the `models/` form the setup
    /// message expects.
    static let modelName = "gemini-3.5-transcribe-live"

    /// Hard ceiling on the wait after `audioStreamEnd`.
    private static let finalizeTimeout: Duration = .seconds(10)

    /// How long the transcript must go untouched after `audioStreamEnd` before
    /// a session with settled text is treated as drained. Long enough to cover
    /// the gap between utterances, short enough not to be felt at the end of a
    /// dictation.
    private static let quietWindow: Duration = .milliseconds(1_200)

    /// How long `start()` waits for `setupComplete`. The socket rejects audio
    /// until the session is configured, so this is on the critical path.
    private static let setupTimeout: Duration = .seconds(5)

    private let logger = Logger(category: .geminiLiveRealtimeDictation)

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    /// Utterances Gemini has settled, in arrival order. Settled utterances are
    /// never resent, so these append; the unsettled tail is held apart.
    private var settledUtterances: [String] = []
    private var interim = ""

    /// When the transcript last changed, used for the quiet-window ending.
    private var lastTranscriptUpdate = ContinuousClock.now

    private var isRunning = false
    private var didSetUp = false
    private var didFinish = false
    private var failureMessage: String?

    /// Text captured so far. Safe to read at any point.
    var currentText: String {
        (settledUtterances + (interim.isEmpty ? [] : [interim]))
            .joined(separator: " ")
    }

    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async {
        guard !isRunning else { return }
        isRunning = true

        var components = URLComponents(
            string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            failureMessage = "invalid Gemini Live WebSocket URL"
            return
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: URLRequest(url: url))
        urlSession = session
        webSocketTask = task
        task.resume()

        // The receive loop starts first so `setupComplete` - and any handshake
        // error - is read by the same code path that reads everything else.
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        do {
            try await sendSetup(on: task, languageHints: languageHints)
        } catch {
            failureMessage = error.localizedDescription
            return
        }

        let deadline = ContinuousClock.now.advanced(by: Self.setupTimeout)
        while !didSetUp, failureMessage == nil, ContinuousClock.now < deadline {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(20))
        }

        if !didSetUp, failureMessage == nil {
            failureMessage = "timed out waiting for setupComplete"
        }
    }

    func send(_ pcmChunk: Data) async {
        guard isRunning, didSetUp, failureMessage == nil, let task = webSocketTask else { return }

        let message: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "data": pcmChunk.base64EncodedString(),
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
        ]

        do {
            guard let json = Self.encode(message) else { return }
            try await task.send(.string(json))
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    func finish() async throws -> String {
        guard isRunning else { throw SessionError.producedNoText }

        if let task = webSocketTask {
            let end: [String: Any] = ["realtimeInput": ["audioStreamEnd": true]]
            if let json = Self.encode(end) {
                try? await task.send(.string(json))
            }
        }

        let deadline = ContinuousClock.now.advanced(by: Self.finalizeTimeout)
        while !didFinish, failureMessage == nil, ContinuousClock.now < deadline {
            if Task.isCancelled { break }
            if hasSettledAndGoneQuiet { break }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let didDrain = didFinish || hasSettledAndGoneQuiet
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        await teardown()

        if let failureMessage {
            throw SessionError.transportFailed(failureMessage)
        }

        // Neither a terminator nor a quiet window: the socket is still mid-flight
        // at the timeout, so what accumulated may be missing its tail and can
        // still hold an unsettled interim. Returning it would silently save a
        // truncated transcript.
        if !didDrain {
            logger.logWarning("Gemini Live finalize timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for the transcript to drain")
        }

        guard !text.isEmpty else { throw SessionError.producedNoText }
        return text
    }

    func cancel() async {
        await teardown()
    }

    // MARK: - Private

    /// True once at least one utterance has settled and nothing has changed for
    /// ``quietWindow``. Requires settled text specifically: a session holding
    /// only an interim has not finished rewriting its tail.
    private var hasSettledAndGoneQuiet: Bool {
        guard !settledUtterances.isEmpty else { return false }
        return lastTranscriptUpdate.duration(to: .now) >= Self.quietWindow
    }

    private func sendSetup(on task: URLSessionWebSocketTask, languageHints: [String]) async throws {
        // "auto" is the absence of a hint here: an empty `languageCodes` asks
        // Gemini to detect the language itself.
        let languageCodes = languageHints.filter { !$0.isEmpty && $0 != "auto" }

        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(Self.modelName)",
                "generationConfig": ["responseModalities": ["TEXT"]],
                "inputAudioTranscription": ["languageCodes": languageCodes]
            ]
        ]

        guard let json = Self.encode(setup) else {
            throw SessionError.transportFailed("could not encode the Live setup message")
        }
        try await task.send(.string(json))
    }

    private static func encode(_ message: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handle(text)
                case .data(let data):
                    // The Live API answers with binary frames carrying JSON as
                    // often as it answers with text ones.
                    if let text = String(data: data, encoding: .utf8) { handle(text) }
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled, failureMessage == nil, !didFinish {
                    failureMessage = error.localizedDescription
                }
                break
            }
        }

        didFinish = true
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if json["setupComplete"] != nil {
            didSetUp = true
            return
        }

        if let error = json["error"] as? [String: Any] {
            let description = (error["message"] as? String) ?? "unknown Gemini Live error"
            logger.logError("Gemini Live realtime error: \(description)")
            failureMessage = description
            return
        }

        guard let serverContent = json["serverContent"] as? [String: Any] else { return }

        // A single event can carry both a settled utterance and a fresh interim,
        // so read both rather than branching on whichever appears first.
        if let settled = Self.transcriptText(serverContent["inputTranscription"]), !settled.isEmpty {
            interim = ""
            settledUtterances.append(settled)
            lastTranscriptUpdate = .now
        }

        if let tail = Self.transcriptText(serverContent["interimInputTranscription"]) {
            interim = tail
            lastTranscriptUpdate = .now
        }

        if serverContent["turnComplete"] as? Bool ?? false
            || serverContent["generationComplete"] as? Bool ?? false {
            didFinish = true
        }
    }

    private static func transcriptText(_ field: Any?) -> String? {
        (field as? [String: Any])?["text"] as? String
    }

    private func teardown() async {
        isRunning = false
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }
}
