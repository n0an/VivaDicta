//
//  SonioxRealtimeTTSClient.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import Foundation
import os

actor SonioxRealtimeTTSClient {
    enum Event: Sendable {
        case audio(Data)
        case finished
        case failed(String)
    }

    static let outputSampleRate: Double = 24000

    private let logger = Logger(category: .liveTranslationTTS)
    private let endpoint = URL(string: "wss://tts-rt.soniox.com/tts-websocket")!
    private let streamID = "vivadicta-\(UUID().uuidString)"

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var continuation: AsyncStream<Event>.Continuation?

    func connect(
        apiKey: String,
        language: LiveTranslationLanguage,
        voice: String
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

        let payload: [String: Any] = [
            "api_key": apiKey,
            "model": "tts-rt-v1-preview",
            "language": language.rawValue,
            "voice": voice,
            "audio_format": "pcm_s16le",
            "sample_rate": Int(Self.outputSampleRate),
            "stream_id": streamID
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let configString = String(data: data, encoding: .utf8) {
            task.send(.string(configString)) { [weak self] error in
                if let error {
                    Task { await self?.emitFailure("config send failed: \(error.localizedDescription)") }
                }
            }
        } else {
            emitFailure("config encode failed")
        }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        return stream
    }

    func sendText(_ text: String, end: Bool = false) {
        guard let task else { return }
        let payload: [String: Any] = [
            "stream_id": streamID,
            "text": text,
            "text_end": end
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        task.send(.string(string)) { [weak self] error in
            if let error {
                Task { await self?.emitFailure("text send failed: \(error.localizedDescription)") }
            }
        }
    }

    func cancelStream() {
        guard let task else { return }
        let payload: [String: Any] = ["stream_id": streamID, "cancel": true]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        task.send(.string(string)) { _ in }
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
        let text: String?
        switch message {
        case .string(let value):
            text = value
        case .data(let data):
            text = String(data: data, encoding: .utf8)
        @unknown default:
            text = nil
        }
        guard let text,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let errorMessage = json["error_message"] as? String, !errorMessage.isEmpty {
            emitFailure(errorMessage)
            return
        }

        if let audioBase64 = json["audio"] as? String,
           !audioBase64.isEmpty,
           let audio = Data(base64Encoded: audioBase64) {
            continuation?.yield(.audio(audio))
        }

        if let terminated = json["terminated"] as? Bool, terminated {
            continuation?.yield(.finished)
            continuation?.finish()
            continuation = nil
        }
    }

    private func emitFailure(_ message: String) {
        logger.logError("TTS WS failure: \(message)")
        continuation?.yield(.failed(message))
        continuation?.finish()
        continuation = nil
    }
}
