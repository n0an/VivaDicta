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

    var config: LiveTranslationConfig = .stored {
        didSet {
            persistConfig(oldValue: oldValue)
            if oldValue.ttsEnabled != config.ttsEnabled, status == .running {
                handleTTSToggle()
            }
            if oldValue.ttsRate != config.ttsRate {
                audio.playbackRate = config.ttsRate
            }
        }
    }

    private let logger = Logger(category: .liveTranslationService)
    private let audio: LiveTranslationAudio
    private let sttClient = SonioxRealtimeSTTClient()
    private var ttsClient: SonioxRealtimeTTSClient?

    private var sttTask: Task<Void, Never>?
    private var ttsTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?
    private var apiKeyCache: String?

    init() {
        audio = LiveTranslationAudio()
        audio.playbackRate = LiveTranslationPreferences.ttsRate
    }

    func clearFailureIfNeeded() {
        if case .failed = status { status = .idle }
    }

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
        apiKeyCache = apiKey

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

        startSTT(apiKey: apiKey)

        if config.ttsEnabled {
            await openTTSStream(apiKey: apiKey)
        }

        captureTask = Task { [weak self] in
            for await chunk in captureStream {
                guard let self else { return }
                await self.sttClient.sendAudioChunk(chunk)
            }
        }

        observeInterruptions()
        status = .running
    }

    private func startSTT(apiKey: String) {
        let vocabularyTerms = CustomVocabulary.getTerms()
        let sourceLang = config.sourceLanguage
        let targetLang = config.targetLanguage
        let sttClient = self.sttClient

        sttTask?.cancel()
        sttTask = Task { [weak self] in
            let stream = await sttClient.connect(
                apiKey: apiKey,
                sourceLanguage: sourceLang,
                targetLanguage: targetLang,
                vocabularyTerms: vocabularyTerms
            )
            for await event in stream {
                guard let self else { return }
                await self.handleSTTEvent(event)
            }
        }
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
            // Only forward FINAL translation tokens to TTS. Soniox revises
            // interim tokens; speaking them produces duplicated/garbled audio.
            if token.kind == .translation, token.isFinal, !token.text.isEmpty {
                await ttsClient?.sendText(token.text)
            }
        case .finished:
            // STT stream ended (idle timeout or server-side close). Reopen if
            // we're still running, mirroring TTS reconnect behaviour.
            guard status == .running, let apiKey = apiKeyCache else { return }
            logger.logInfo("STT stream ended mid-session - reconnecting")
            startSTT(apiKey: apiKey)
        case .failed(let message):
            // Only treat as fatal when not running; transient network blips
            // mid-session reconnect transparently.
            if status == .running, let apiKey = apiKeyCache {
                logger.logInfo("STT stream failed mid-session - reconnecting: \(message)")
                startSTT(apiKey: apiKey)
            } else {
                await fail(LiveTranslationError.webSocketFailure(message))
            }
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
        // If the trailing token is non-final, replace it with the incoming
        // token (whether final or not). Soniox emits interim tokens that get
        // superseded; this keeps the rendered text from doubling. Multi-token
        // interim tails are not perfectly preserved - acceptable trade-off.
        if let last = list.last, !last.isFinal {
            list.removeLast()
        }
        list.append(token)
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
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }

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
        apiKeyCache = nil

        audio.stop()
    }

    private func observeInterruptions() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard self != nil,
                  let info = notification.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
                return
            }
            Task { @MainActor [weak self] in
                await self?.handleInterruption(type: type)
            }
        }
    }

    private func handleInterruption(type: AVAudioSession.InterruptionType) async {
        switch type {
        case .began:
            logger.logInfo("Audio session interrupted - stopping live translation")
            await fail(LiveTranslationError.audioSessionFailure("Interrupted by another app"))
        case .ended:
            // We don't auto-resume; user must restart explicitly. Resuming a
            // mid-translation session after interruption produces inconsistent
            // STT context anyway.
            break
        @unknown default:
            break
        }
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
        await AVAudioApplication.requestRecordPermission()
    }

    private func persistConfig(oldValue: LiveTranslationConfig) {
        if oldValue.sourceLanguage != config.sourceLanguage {
            LiveTranslationPreferences.sourceLanguage = config.sourceLanguage
        }
        if oldValue.targetLanguage != config.targetLanguage {
            LiveTranslationPreferences.targetLanguage = config.targetLanguage
        }
        if oldValue.ttsEnabled != config.ttsEnabled {
            LiveTranslationPreferences.ttsEnabled = config.ttsEnabled
        }
        if oldValue.ttsRate != config.ttsRate {
            LiveTranslationPreferences.ttsRate = config.ttsRate
        }
    }

    private func renderText(from tokens: [LiveTranslationToken]) -> String {
        tokens
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
