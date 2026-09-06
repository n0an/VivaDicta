//
//  CartesiaRealtimeSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.09.06
//

import Foundation
import os

/// Drives one dictation over Cartesia's Ink WebSocket.
///
/// Realtime-only, like Flux and Voxtral Realtime: the batch `/stt` endpoint
/// accepts the `ink-whisper` family and nothing else, so an `ink-2` selection
/// that reaches the upload path transcribes as `ink-whisper` instead - which is
/// what `TranscriptionModelProvider.asyncEquivalent(of:)` maps it to.
///
/// The protocol is interim/final, with one wrinkle worth stating: a chunk with
/// `is_final` is a **delta from the previous final**, not a restatement of the
/// transcript so far, so finals concatenate. Non-final chunks are the unsettled
/// tail and replace each other. Same rule as Deepgram Nova, and the reason
/// `settledChunks` and `interim` are held apart.
///
/// The socket version is pinned separately from `CartesiaTranscriptionService`'s
/// batch header: `/stt/websocket` requires `2026-08-14`, while the upload path
/// stays on the version it was verified against.
actor CartesiaRealtimeSession: RealtimeDictationSession {
    typealias SessionError = RealtimeDictationSessionError

    /// The `cartesia_version` the WebSocket endpoint requires. Independent of
    /// `CartesiaTranscriptionService.cartesiaVersion`, which pins the batch API.
    private static let socketVersion = "2026-08-14"

    /// How long `finish()` waits for the `done` acknowledgement after `close`.
    /// Streaming has already delivered the settled chunks by then, so this is a
    /// tail-latency guard, not the main wait.
    private static let finalizeTimeout: Duration = .seconds(10)

    /// Cartesia caps keyterms at 100 terms and 1,200 characters combined;
    /// exceeding either is rejected at the handshake, so both are enforced here.
    private static let maxKeyterms = 100
    private static let maxKeytermCharacters = 1_200

    private let logger = Logger(category: .cartesiaRealtimeDictation)

    /// The Ink model this socket runs, e.g. `ink-2`.
    private let modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    /// Finalized deltas in arrival order. Cartesia never resends one, so these
    /// append; the unsettled tail is held apart and replaced.
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

        var components = URLComponents(string: "wss://api.cartesia.ai/stt/websocket")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "encoding", value: "pcm_s16le"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "cartesia_version", value: Self.socketVersion)
        ]

        // `language` is an ink-whisper parameter; ink-2 detects the language
        // itself and rejects the field, so hints are deliberately not sent.
        // Custom vocabulary goes over as keyterms instead, which ink-2 accepts.
        for term in Self.keyterms(from: vocabularyTerms) {
            queryItems.append(URLQueryItem(name: "keyterm", value: term))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            failureMessage = "invalid Cartesia WebSocket URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

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

        // `finalize` transcribes whatever audio is still buffered server-side;
        // `close` then flushes and asks for the `done` acknowledgement this
        // waits on. Sending only `close` would race the buffered tail.
        if let task = webSocketTask {
            try? await task.send(.string("finalize"))
            try? await task.send(.string("close"))
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

        // A timeout means Cartesia never acknowledged `close`, so what
        // accumulated may be missing its tail and can still hold an unsettled
        // interim. Returning it would silently save a truncated transcript.
        if didTimeOut {
            logger.logWarning("Cartesia finalize timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for the done acknowledgement")
        }

        guard !text.isEmpty else { throw SessionError.producedNoText }
        return text
    }

    func cancel() async {
        await teardown()
    }

    // MARK: - Private

    /// Trims custom vocabulary to what the handshake accepts: at most
    /// ``maxKeyterms`` terms, and at most ``maxKeytermCharacters`` across them.
    /// `nonisolated` so it can be reasoned about - and tested - without the actor.
    nonisolated static func keyterms(from vocabularyTerms: [String]) -> [String] {
        var accepted: [String] = []
        var characters = 0

        for term in vocabularyTerms where !term.isEmpty {
            guard accepted.count < maxKeyterms else { break }
            guard characters + term.count <= maxKeytermCharacters else { continue }
            accepted.append(term)
            characters += term.count
        }

        return accepted
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        switch json["type"] as? String {
        case "transcript":
            ingestTranscript(json)

        case "done":
            // Cartesia's acknowledgement of `close`, sent after the last chunk.
            didFinish = true

        case "flush_done":
            // Acknowledges `finalize` only; the session is still open, so this
            // is not the signal `finish()` waits on.
            return

        case "error":
            let description = (json["message"] as? String) ?? "unknown Cartesia error"
            logger.logError("Cartesia realtime error: \(description)")
            failureMessage = description

        default:
            return
        }
    }

    private func ingestTranscript(_ json: [String: Any]) {
        guard let chunk = json["text"] as? String else { return }

        if json["is_final"] as? Bool ?? false {
            interim = ""
            guard !chunk.isEmpty else { return }
            settledChunks.append(chunk)
        } else {
            interim = chunk
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
