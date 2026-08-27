//
//  DeepgramNovaRealtimeSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.27
//

import Foundation
import os

/// Drives one dictation over Deepgram Nova's realtime WebSocket.
///
/// Nova is the same slug on both paths - `/v1/listen` serves it over a socket
/// and over an upload - so a fallback needs no model substitution, unlike Flux.
///
/// The protocol is interim/final: `is_final` settles a chunk and is never
/// resent, while interim results replace the unsettled tail. Finals therefore
/// accumulate and interims are rebuilt per message, which is the same rule
/// `RealtimeTranscriptAccumulator` applies to Soniox tokens - just expressed
/// over whole transcript strings rather than tokens.
actor DeepgramNovaRealtimeSession: RealtimeDictationSession {
    typealias SessionError = RealtimeDictationSessionError

    /// How long `finish()` waits for Deepgram to flush after end-of-audio.
    /// Streaming has already delivered the settled chunks by then, so this is a
    /// tail-latency guard, not the main wait.
    private static let finalizeTimeout: Duration = .seconds(10)

    /// Deepgram is sent at most this many keyterms; more bloats the handshake URL.
    private static let maxKeyterms = 50

    private let logger = Logger(category: .deepgramNovaRealtimeDictation)

    /// `nova-3` or `nova-3-medical`. The medical build is English-only.
    private let modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    /// Chunks Deepgram has settled, in order. Deepgram does not resend a settled
    /// chunk, so these append; the unsettled tail is held apart and replaced.
    private var settledChunks: [String] = []
    private var interim = ""

    private var isRunning = false
    private var didFinish = false
    private var failureMessage: String?

    /// Text captured so far. Safe to read at any point.
    var currentText: String {
        (settledChunks + (interim.isEmpty ? [] : [interim]))
            .joined(separator: " ")
    }

    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async {
        guard !isRunning else { return }
        isRunning = true

        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "numerals", value: "true"),
            URLQueryItem(name: "interim_results", value: "true")
        ]

        // Omitting `language` is what asks Deepgram to auto-detect, so "auto"
        // sends nothing at all.
        for hint in languageHints where !hint.isEmpty && hint != "auto" {
            queryItems.append(URLQueryItem(name: "language", value: hint))
        }

        for term in vocabularyTerms.prefix(Self.maxKeyterms) {
            queryItems.append(URLQueryItem(name: "keyterm", value: term))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            failureMessage = "invalid Deepgram WebSocket URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

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
            try await task.send(.data(pcmChunk))
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    func finish() async throws -> String {
        guard isRunning else { throw SessionError.producedNoText }

        // `Finalize` flushes the audio buffered server-side; `CloseStream` then
        // tells Deepgram no more is coming, which is what makes it send the
        // closing `Metadata` this waits on.
        if let task = webSocketTask {
            try? await task.send(.string(#"{"type":"Finalize"}"#))
            try? await task.send(.string(#"{"type":"CloseStream"}"#))
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

        // A timeout means Deepgram never confirmed it was done, so what
        // accumulated may be missing its tail and can still hold an unsettled
        // interim. Returning it would silently save a truncated transcript.
        if didTimeOut {
            logger.logWarning("Deepgram finalize timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for final results")
        }

        guard !text.isEmpty else { throw SessionError.producedNoText }
        return text
    }

    func cancel() async {
        await teardown()
    }

    // MARK: - Private

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

        // The socket closing is Deepgram's acknowledgement of `CloseStream`.
        didFinish = true
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        switch json["type"] as? String {
        case "Metadata":
            // Deepgram's end-of-stream summary, sent after the last transcript.
            didFinish = true
            return
        case "Error":
            let description = (json["description"] as? String)
                ?? (json["message"] as? String)
                ?? "unknown Deepgram error"
            logger.logError("Deepgram realtime error: \(description)")
            failureMessage = description
            return
        default:
            break
        }

        guard let channel = json["channel"] as? [String: Any],
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String else {
            return
        }

        let isFinal = (json["is_final"] as? Bool ?? false)
            || (json["speech_final"] as? Bool ?? false)

        if isFinal {
            interim = ""
            guard !transcript.isEmpty else { return }
            settledChunks.append(transcript)
        } else {
            interim = transcript
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
