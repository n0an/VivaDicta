//
//  DeepgramFluxRealtimeSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.27
//

import Foundation
import os

/// Drives one dictation over Deepgram Flux's realtime WebSocket.
///
/// Flux is a different socket from Nova, not a different model on the same one:
/// it speaks `/v2/listen` and has no pre-recorded counterpart at all, which is
/// why `TranscriptionModelProvider.asyncEquivalent(of:)` maps it to Nova 3 for
/// the upload fallback.
///
/// The protocol is turn-based rather than interim/final. Each `TurnInfo` carries
/// the whole current turn's transcript, replacing what came before it, and only
/// `EndOfTurn` settles a turn. `EagerEndOfTurn` is a guess Flux can still walk
/// back with `TurnResumed`, so committing on it would keep text the model has
/// not settled on.
actor DeepgramFluxRealtimeSession: RealtimeDictationSession {
    typealias SessionError = RealtimeDictationSessionError

    /// How long `finish()` waits for Flux to close the open turn after
    /// end-of-audio. Streaming has already delivered the settled turns by then,
    /// so this is a tail-latency guard, not the main wait.
    private static let finalizeTimeout: Duration = .seconds(10)

    private let logger = Logger(category: .deepgramFluxRealtimeDictation)

    /// `flux-general-en` or `flux-general-multi`. Only the multilingual build
    /// accepts `language_hint`, so the English one silently ignores hints.
    private let modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    /// Turns Flux has settled, in order. A turn's transcript is resent in full
    /// on every update, so the live turn is held separately and replaced rather
    /// than appended - appending would duplicate every word as it firms up.
    private var settledTurns: [String] = []
    private var openTurn = ""

    private var isRunning = false
    private var didFinish = false
    private var failureMessage: String?

    /// Text captured so far. Safe to read at any point.
    var currentText: String {
        (settledTurns + (openTurn.isEmpty ? [] : [openTurn]))
            .joined(separator: " ")
    }

    func start(apiKey: String, languageHints: [String], vocabularyTerms: [String]) async {
        guard !isRunning else { return }
        isRunning = true

        var components = URLComponents(string: "wss://api.deepgram.com/v2/listen")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "numerals", value: "true")
        ]

        // Flux takes `language_hint`, not `language`, and omitting it is what
        // asks the model to auto-detect - so "auto" sends nothing at all.
        let acceptsHints = modelName == TranscriptionModelProvider.deepgramFluxMultilingualModel
        for hint in languageHints where acceptsHints && !hint.isEmpty && hint != "auto" {
            queryItems.append(URLQueryItem(name: "language_hint", value: hint))
        }

        for term in vocabularyTerms.prefix(50) {
            queryItems.append(URLQueryItem(name: "keyterm", value: term))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            failureMessage = "invalid Flux WebSocket URL"
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

        // Flux has no Finalize message - `CloseStream` is what tells it no more
        // audio is coming, and it closes the open turn in response.
        if let task = webSocketTask {
            let closeMessage = #"{"type":"CloseStream"}"#
            try? await task.send(.string(closeMessage))
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

        // A timeout means Flux never closed the turn, so what accumulated may
        // be missing its tail and can still hold an unsettled turn. Returning
        // it would silently save a truncated transcript.
        if didTimeOut {
            logger.logWarning("Flux finalize timed out; deferring to the upload fallback")
            throw SessionError.transportFailed("timed out waiting for end of turn")
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

        // The socket closing is Flux's acknowledgement of `CloseStream`.
        didFinish = true
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "TurnInfo":
            applyTurnInfo(json)
        case "FatalError":
            let description = json["description"] as? String ?? "unknown Flux error"
            logger.logError("Flux fatal error: \(description)")
            failureMessage = description
        default:
            return
        }
    }

    private func applyTurnInfo(_ json: [String: Any]) {
        let transcript = (json["transcript"] as? String) ?? ""

        switch json["event"] as? String {
        case "EndOfTurn":
            if !transcript.isEmpty { settledTurns.append(transcript) }
            openTurn = ""
        case "StartOfTurn", "Update", "EagerEndOfTurn", "TurnResumed":
            openTurn = transcript
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
