//
//  SonioxRealtimeSTTClient.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import Foundation
import os

actor SonioxRealtimeSTTClient {
    enum Event: Sendable {
        case token(LiveTranslationToken)
        case finished
        case failed(String)
    }

    private let logger = Logger(category: .liveTranslationSTT)
    private let endpoint = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var continuation: AsyncStream<Event>.Continuation?

    func connect(
        apiKey: String,
        sourceLanguage: LiveTranslationLanguage,
        targetLanguage: LiveTranslationLanguage,
        vocabularyTerms: [String]
    ) -> AsyncStream<Event> {
        disconnect()

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: endpoint)
        self.task = task

        let stream = AsyncStream<Event> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.disconnect() }
            }
        }

        task.resume()

        do {
            let config = makeConfigPayload(
                apiKey: apiKey,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                vocabularyTerms: vocabularyTerms
            )
            let data = try JSONSerialization.data(withJSONObject: config)
            let message = URLSessionWebSocketTask.Message.string(String(decoding: data, as: UTF8.self))
            task.send(message) { [weak self] error in
                if let error {
                    Task { await self?.emitFailure("config send failed: \(error.localizedDescription)") }
                }
            }
        } catch {
            emitFailure("config encode failed: \(error.localizedDescription)")
        }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        return stream
    }

    func sendAudioChunk(_ data: Data) {
        guard let task else { return }
        task.send(.data(data)) { [weak self] error in
            if let error {
                Task { await self?.emitFailure("audio send failed: \(error.localizedDescription)") }
            }
        }
    }

    func finalizeAudio() {
        guard let task else { return }
        task.send(.string("")) { _ in }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Private

    private func makeConfigPayload(
        apiKey: String,
        sourceLanguage: LiveTranslationLanguage,
        targetLanguage: LiveTranslationLanguage,
        vocabularyTerms: [String]
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "api_key": apiKey,
            "model": "stt-rt-v4",
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "num_channels": 1,
            "language_hints": [sourceLanguage.rawValue],
            "language_hints_strict": true,
            "enable_language_identification": true,
            "enable_endpoint_detection": true,
            "translation": [
                "type": "one_way",
                "target_language": targetLanguage.rawValue
            ]
        ]

        if !vocabularyTerms.isEmpty {
            payload["context"] = ["terms": vocabularyTerms]
        }

        return payload
    }

    private func receiveLoop() async {
        guard let task else { return }
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                handleMessage(message)
            } catch {
                if !Task.isCancelled {
                    emitFailure("receive failed: \(error.localizedDescription)")
                }
                return
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            decodeAndEmit(text: text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                decodeAndEmit(text: text)
            }
        @unknown default:
            break
        }
    }

    private func decodeAndEmit(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let errorMessage = json["error_message"] as? String, !errorMessage.isEmpty {
            emitFailure(errorMessage)
            return
        }

        if let tokens = json["tokens"] as? [[String: Any]] {
            for tokenJson in tokens {
                emitToken(from: tokenJson)
            }
        }

        if let finished = json["finished"] as? Bool, finished {
            continuation?.yield(.finished)
            continuation?.finish()
            continuation = nil
        }
    }

    private func emitToken(from json: [String: Any]) {
        guard let text = json["text"] as? String, !text.isEmpty else { return }

        // Soniox emits angle-bracketed marker tokens like "<end>" for endpoint
        // detection (we enable it for better token finalisation latency).
        // They're control signals, not visible transcript text - drop them.
        if text.hasPrefix("<") && text.hasSuffix(">") {
            return
        }

        let isFinal = json["is_final"] as? Bool ?? false
        let translationStatus = (json["translation_status"] as? String)?.lowercased() ?? "original"
        let kind: LiveTranslationToken.Kind = translationStatus == "translation" ? .translation : .original

        let token = LiveTranslationToken(
            id: UUID(),
            text: text,
            isFinal: isFinal,
            kind: kind
        )
        continuation?.yield(.token(token))
    }

    private func emitFailure(_ message: String) {
        logger.logError("STT WS failure: \(message)")
        continuation?.yield(.failed(message))
        continuation?.finish()
        continuation = nil
    }
}
