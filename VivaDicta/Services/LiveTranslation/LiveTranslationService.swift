//
//  LiveTranslationService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import AVFoundation
import Foundation
import os

@MainActor
@Observable
final class LiveTranslationService {
    private(set) var status: LiveTranslationStatus = .idle
    private(set) var originalTokens: [LiveTranslationToken] = []
    private(set) var translatedTokens: [LiveTranslationToken] = []

    var config = LiveTranslationConfig.default {
        didSet {
            if oldValue.ttsEnabled != config.ttsEnabled, status == .running {
                handleTTSToggle()
            }
        }
    }

    private let logger = Logger(category: .liveTranslationService)
    private let audio = LiveTranslationAudio()
    private let sttClient = SonioxRealtimeSTTClient()
    private var ttsClient: SonioxRealtimeTTSClient?

    private var sttTask: Task<Void, Never>?
    private var ttsTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?

    func start() async {
        guard status == .idle || isFailed(status) else { return }

        status = .starting
        originalTokens.removeAll()
        translatedTokens.removeAll()

        guard let apiKey = KeychainService.shared.getString(forKey: "sonioxAPIKey"),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await fail(LiveTranslationError.missingAPIKey)
            return
        }

        guard await requestMicrophonePermission() else {
            await fail(LiveTranslationError.microphonePermissionDenied)
            return
        }

        let captureStream = audio.makeCaptureStream()

        do {
            try await audio.start()
        } catch {
            await fail(error)
            return
        }

        let vocabularyTerms = CustomVocabulary.getTerms()
        let sttStream = await sttClient.connect(
            apiKey: apiKey,
            sourceLanguage: config.sourceLanguage,
            targetLanguage: config.targetLanguage,
            vocabularyTerms: vocabularyTerms
        )

        if config.ttsEnabled {
            await openTTSStream(apiKey: apiKey)
        }

        captureTask = Task { [weak self] in
            for await chunk in captureStream {
                guard let self else { return }
                await self.sttClient.sendAudioChunk(chunk)
            }
        }

        sttTask = Task { [weak self] in
            for await event in sttStream {
                guard let self else { return }
                await self.handleSTTEvent(event)
            }
        }

        status = .running
    }

    func stop() async {
        guard status == .running || status == .starting else { return }
        status = .stopping
        await teardown()
        status = .idle
    }

    func transcriptSnapshot() -> (original: String, translation: String) {
        let original = renderText(from: originalTokens)
        let translation = renderText(from: translatedTokens)
        return (original, translation)
    }

    // MARK: - Private

    private func handleSTTEvent(_ event: SonioxRealtimeSTTClient.Event) async {
        switch event {
        case .token(let token):
            appendToken(token)
            if token.kind == .translation, !token.text.isEmpty {
                await ttsClient?.sendText(token.text)
            }
        case .finished:
            break
        case .failed(let message):
            await fail(LiveTranslationError.webSocketFailure(message))
        }
    }

    private func handleTTSEvent(_ event: SonioxRealtimeTTSClient.Event) async {
        switch event {
        case .audio(let data):
            audio.enqueuePlayback(data)
        case .finished:
            // Soniox auto-terminates a TTS stream after some duration. If we're
            // still in a running session and TTS is still enabled, transparently
            // reopen the stream so playback continues.
            guard status == .running, config.ttsEnabled else { return }
            logger.logInfo("TTS stream ended mid-session - reconnecting")
            await reopenTTSStream()
        case .failed(let message):
            logger.logError("TTS stream failed: \(message)")
            guard status == .running, config.ttsEnabled else { return }
            logger.logInfo("TTS stream failed mid-session - reconnecting")
            await reopenTTSStream()
        }
    }

    private func reopenTTSStream() async {
        await ttsClient?.disconnect()
        ttsClient = nil
        ttsTask?.cancel()
        ttsTask = nil

        guard let apiKey = KeychainService.shared.getString(forKey: "sonioxAPIKey"),
              !apiKey.isEmpty else { return }
        await openTTSStream(apiKey: apiKey)
    }

    private func appendToken(_ token: LiveTranslationToken) {
        switch token.kind {
        case .original:
            mergeToken(token, into: &originalTokens)
        case .translation:
            mergeToken(token, into: &translatedTokens)
        }
    }

    private func mergeToken(_ token: LiveTranslationToken, into list: inout [LiveTranslationToken]) {
        if let last = list.last, last.isFinal == false {
            if token.isFinal {
                list.removeLast()
                list.append(token)
            } else {
                list.removeLast()
                list.append(token)
            }
        } else {
            list.append(token)
        }
    }

    private func openTTSStream(apiKey: String) async {
        let client = SonioxRealtimeTTSClient()
        ttsClient = client
        let stream = await client.connect(
            apiKey: apiKey,
            language: config.targetLanguage,
            voice: config.ttsVoice
        )
        ttsTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await self.handleTTSEvent(event)
            }
        }
    }

    private func handleTTSToggle() {
        Task { [weak self] in
            guard let self else { return }
            if self.config.ttsEnabled {
                guard let apiKey = KeychainService.shared.getString(forKey: "sonioxAPIKey"),
                      !apiKey.isEmpty else { return }
                await self.openTTSStream(apiKey: apiKey)
            } else {
                await self.ttsClient?.disconnect()
                self.ttsClient = nil
                self.ttsTask?.cancel()
                self.ttsTask = nil
            }
        }
    }

    private func teardown() async {
        captureTask?.cancel()
        captureTask = nil
        sttTask?.cancel()
        sttTask = nil
        ttsTask?.cancel()
        ttsTask = nil

        await sttClient.finalizeAudio()
        await sttClient.disconnect()
        await ttsClient?.disconnect()
        ttsClient = nil

        audio.stop()
    }

    private func fail(_ error: Error) async {
        let message: String
        if let translationError = error as? LiveTranslationError {
            message = translationError.errorDescription ?? "Unknown error"
        } else {
            message = error.localizedDescription
        }
        logger.logError("Live translation failed: \(message)")
        await teardown()
        status = .failed(message)
    }

    private func isFailed(_ status: LiveTranslationStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }

    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func renderText(from tokens: [LiveTranslationToken]) -> String {
        tokens
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
