//
//  MistralRealtimeSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.27
//

import Foundation
import os

/// Drives one dictation over Mistral's Voxtral Realtime WebSocket.
///
/// Realtime-only, like Flux: `voxtral-mini-transcribe-realtime-2602` is rejected
/// by the batch `/v1/audio/transcriptions` endpoint, so a selection that reaches
/// the upload path transcribes as `voxtral-mini-latest` instead - which is what
/// `TranscriptionModelProvider.asyncEquivalent(of:)` maps it to.
///
/// The protocol is delta-based rather than interim/final: every
/// `transcription.text.delta` is new text appended to what came before, never a
/// replacement, so there is no unsettled tail to hold apart. `transcription.done`
/// closes the transcript.
///
/// The socket takes neither a language hint nor a vocabulary parameter, so both
/// are accepted to satisfy the protocol and go unused.
actor MistralRealtimeSession: RealtimeDictationSession {
    typealias SessionError = RealtimeDictationSessionError

    /// How long `finish()` waits for `transcription.done` after end-of-audio.
    private static let finalizeTimeout: Duration = .seconds(10)

    private let logger = Logger(category: .mistralRealtimeDictation)

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    /// Every delta is additive, so this is a plain running concatenation.
    private var transcript = ""

    private var isRunning = false
    private var didFinish = false
    private var failureMessage: String?

    /// Text captured so far. Safe to read at any point.
    var currentText: String { transcript }

    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async {
        guard !isRunning else { return }
        isRunning = true

        var components = URLComponents(string: "wss://api.mistral.ai/v1/audio/transcriptions/realtime")!
        components.queryItems = [
            URLQueryItem(name: "model", value: TranscriptionModelProvider.mistralRealtimeModel)
        ]

        guard let url = components.url else {
            failureMessage = "invalid Mistral WebSocket URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        urlSession = session
        webSocketTask = task
        task.resume()

        // Mistral will not accept audio until the session's format is declared,
        // and the socket reports `session.created` first. Both happen here so
        // the pump can start sending immediately after `start()` returns.
        do {
            try await declareAudioFormat(on: task)
        } catch {
            failureMessage = error.localizedDescription
            return
        }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func send(_ pcmChunk: Data) async {
        guard isRunning, failureMessage == nil, let task = webSocketTask else { return }

        let message: [String: Any] = [
            "type": "input_audio.append",
            "audio": pcmChunk.base64EncodedString()
        ]

        do {
            guard let data = try? JSONSerialization.data(withJSONObject: message),
                  let json = String(data: data, encoding: .utf8) else { return }
            try await task.send(.string(json))
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    func finish() async throws -> String {
        guard isRunning else { throw SessionError.producedNoText }

        if let task = webSocketTask {
            try? await task.send(.string(#"{"type":"input_audio.end"}"#))
        }

        let deadline = ContinuousClock.now.advanced(by: Self.finalizeTimeout)
        while !didFinish, failureMessage == nil, ContinuousClock.now < deadline {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let didTimeOut = !didFinish && failureMessage == nil
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        await teardown()

        if let failureMessage {
            throw SessionError.transportFailed(failureMessage)
        }

        // A timeout means `transcription.done` never arrived, so the deltas that
        // accumulated may be missing the tail. Returning them would silently
        // save a truncated transcript.
        if didTimeOut {
            logger.logWarning("Voxtral finalize timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for transcription.done")
        }

        guard !text.isEmpty else { throw SessionError.producedNoText }
        return text
    }

    func cancel() async {
        await teardown()
    }

    // MARK: - Private

    /// Waits for `session.created`, then declares the PCM format the capture
    /// side produces.
    private func declareAudioFormat(on task: URLSessionWebSocketTask) async throws {
        let opened = try await task.receive()
        if case .string(let text) = opened,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["type"] as? String == "error" {
            throw SessionError.transportFailed(Self.errorMessage(from: json))
        }

        let message: [String: Any] = [
            "type": "session.update",
            "session": [
                "audio_format": [
                    "encoding": "pcm_s16le",
                    "sample_rate": 16000
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: message)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SessionError.transportFailed("could not encode session.update")
        }
        try await task.send(.string(json))
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
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "transcription.text.delta":
            transcript += (json["text"] as? String) ?? ""

        case "transcription.done":
            didFinish = true

        case "transcription.segment":
            // Deliberately ignored: the segment's text has already arrived as
            // deltas, so accumulating it here would duplicate every sentence.
            return

        case "error":
            let description = Self.errorMessage(from: json)
            logger.logError("Voxtral realtime error: \(description)")
            failureMessage = description

        default:
            return
        }
    }

    private static func errorMessage(from json: [String: Any]) -> String {
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return (json["message"] as? String) ?? "unknown Mistral error"
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
