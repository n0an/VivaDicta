//
//  ElevenLabsRealtimeSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.27
//

import Foundation
import os

/// Drives one dictation over ElevenLabs Scribe's realtime WebSocket.
///
/// The socket takes `scribe_v2_realtime` while the upload path takes `scribe_v2`
/// - the same model, a different slug per transport - so `asyncEquivalent(of:)`
/// leaves the user's selection alone and only this session substitutes.
///
/// Audio goes up base64-encoded inside JSON rather than as binary frames, which
/// is ElevenLabs-specific and costs a third more bytes than the raw PCM.
///
/// `commit_strategy=vad` lets the server decide where a segment ends. Each
/// `committed_transcript` is one settled segment and is never resent, so
/// segments accumulate while `partial_transcript` replaces the unsettled tail.
actor ElevenLabsRealtimeSession: RealtimeDictationSession {
    typealias SessionError = RealtimeDictationSessionError

    /// How long `finish()` waits for the server to return the last segment after
    /// the commit. Streaming has already delivered the rest by then.
    private static let finalizeTimeout: Duration = .seconds(10)

    private let logger = Logger(category: .elevenLabsRealtimeDictation)

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    /// Segments the server has committed, in order, plus the unsettled tail held
    /// apart so it can be replaced rather than appended.
    private var committedSegments: [String] = []
    private var partial = ""

    private var isRunning = false
    private var didFinish = false
    private var failureMessage: String?

    /// Set once `finish()` has asked for the closing commit.
    ///
    /// `commit_strategy=vad` means the server also commits mid-speech at every
    /// pause it detects, so a `committed_transcript` on its own says nothing
    /// about end-of-audio - only one arriving after this flag is set does.
    private var didRequestCommit = false

    /// Text captured so far. Safe to read at any point.
    var currentText: String {
        (committedSegments + (partial.isEmpty ? [] : [partial]))
            .joined(separator: " ")
    }

    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async {
        guard !isRunning else { return }
        isRunning = true

        var components = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model_id", value: "scribe_v2_realtime"),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "vad")
        ]

        // Omitting `language_code` is what asks Scribe to auto-detect.
        for hint in languageHints where !hint.isEmpty && hint != "auto" {
            queryItems.append(URLQueryItem(name: "language_code", value: hint))
        }

        // The realtime socket takes no vocabulary parameter - `vocabularyTerms`
        // is accepted to satisfy the protocol and deliberately unused.

        components.queryItems = queryItems

        guard let url = components.url else {
            failureMessage = "invalid ElevenLabs WebSocket URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        urlSession = session
        webSocketTask = task
        task.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func send(_ pcmChunk: Data) async {
        guard isRunning, failureMessage == nil, let task = webSocketTask else { return }
        do {
            try await task.send(.string(Self.audioMessage(pcmChunk.base64EncodedString(), commit: false)))
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    func finish() async throws -> String {
        guard isRunning else { throw SessionError.producedNoText }

        // An empty chunk with `commit: true` is how ElevenLabs is told to settle
        // whatever audio is still open. Flag it first so the segment that comes
        // back is recognised as the acknowledgement.
        didRequestCommit = true
        if let task = webSocketTask {
            try? await task.send(.string(Self.audioMessage("", commit: true)))
        }

        let deadline = ContinuousClock.now.advanced(by: Self.finalizeTimeout)
        while !didFinish, failureMessage == nil, ContinuousClock.now < deadline {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let didTimeOut = !didFinish && failureMessage == nil
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        await teardown()

        if let failureMessage {
            throw SessionError.transportFailed(failureMessage)
        }

        // A timeout means the commit was never acknowledged, so what accumulated
        // may be missing its tail and can still hold an unsettled partial.
        // Returning it would silently save a truncated transcript.
        if didTimeOut {
            logger.logWarning("Scribe commit timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for the committed transcript")
        }

        guard !text.isEmpty else { throw SessionError.producedNoText }
        return text
    }

    func cancel() async {
        await teardown()
    }

    // MARK: - Private

    private static func audioMessage(_ base64Audio: String, commit: Bool) -> String {
        let message: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": base64Audio,
            "commit": commit,
            "sample_rate": 16000
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["message_type"] as? String else {
            return
        }

        switch messageType {
        case "session_started":
            return

        case "partial_transcript":
            partial = (json["text"] as? String) ?? ""

        case "committed_transcript", "committed_transcript_with_timestamps":
            partial = ""
            if let transcript = json["text"] as? String, !transcript.isEmpty {
                committedSegments.append(transcript)
            }
            // Only a segment arriving after our own commit means end-of-audio;
            // the VAD-driven ones during speech must not end the wait. An empty
            // one still counts - it is how a commit with nothing left is
            // answered.
            if didRequestCommit { didFinish = true }

        case "error", "auth_error", "quota_exceeded", "rate_limited",
             "resource_exhausted", "session_time_limit_exceeded",
             "input_error", "chunk_size_exceeded", "transcriber_error":
            let description = (json["message"] as? String) ?? messageType
            logger.logError("Scribe realtime error: \(messageType) - \(description)")
            failureMessage = description

        default:
            return
        }
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
