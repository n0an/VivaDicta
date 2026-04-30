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

    /// Bounded retry state for STT reconnect on `.failed` events. Prevents a
    /// busy reconnect loop when the failure is persistent (revoked key, quota,
    /// malformed config). Reset on successful token receipt or graceful close.
    private var sttFailureRetries: Int = 0
    private let maxSTTFailureRetries: Int = 3

    /// Same bounded retry state for TTS reconnect. Without this a persistent
    /// TTS failure (e.g., voice not supported for target language) loops the
    /// reopen path on MainActor and can starve SwiftUI updates - which is
    /// what was hanging the Save and Stop buttons in practice.
    private var ttsFailureRetries: Int = 0
    private let maxTTSFailureRetries: Int = 3

    /// Source/target language captured at session start. `combineSnapshot`
    /// uses these so save-as-note labels never reflect a picker change made
    /// after Stop and before tapping Save.
    private(set) var sessionSourceLanguage: LiveTranslationLanguage = .english
    private(set) var sessionTargetLanguage: LiveTranslationLanguage = .english

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
        sttFailureRetries = 0
        ttsFailureRetries = 0
        sessionSourceLanguage = config.sourceLanguage
        sessionTargetLanguage = config.targetLanguage

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

        // After every suspension point we re-check status. If a concurrent
        // fail() (e.g. STT WS rejected the config and emitted .failed) tore
        // the session down, we must not create more orphan resources.
        guard status == .starting else { return }

        startSTT(apiKey: apiKey)

        if config.ttsEnabled {
            await openTTSStream(apiKey: apiKey)
        }

        guard status == .starting else { return }

        captureTask = Task { [weak self] in
            for await chunk in captureStream {
                guard let self else { return }
                await self.sttClient.sendAudioChunk(chunk)
            }
        }

        observeInterruptions()

        // Reconcile TTS toggle changes that happened mid-startup. The didSet
        // observer ignores changes while status == .starting (because the
        // start() flow hasn't yet reached the openTTSStream call); apply the
        // current desired state here once setup is otherwise complete.
        if config.ttsEnabled, ttsClient == nil {
            await openTTSStream(apiKey: apiKey)
        } else if !config.ttsEnabled, ttsClient != nil {
            await closeTTSStream()
        }

        // Only transition to .running if the user (or a failure) didn't move
        // us elsewhere while we were suspended on the awaits above. Otherwise
        // we'd revive a session that's already been torn down by stop()/fail().
        if status == .starting {
            status = .running
        }
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

    func transcriptSnapshot() -> (
        sourceLanguage: LiveTranslationLanguage,
        original: String,
        targetLanguage: LiveTranslationLanguage,
        translation: String
    ) {
        let original = renderText(from: originalTokens)
        let translation = renderText(from: translatedTokens)
        return (sessionSourceLanguage, original, sessionTargetLanguage, translation)
    }

    // MARK: - Private

    private func handleSTTEvent(_ event: SonioxRealtimeSTTClient.Event) async {
        switch event {
        case .tokens(let batch):
            // Successful token receipt means the connection is healthy; reset
            // the failure retry counter so future transient blips have a fresh
            // budget.
            sttFailureRetries = 0
            appendTokens(batch)
            // Only forward FINAL translation tokens to TTS. Soniox revises
            // interim tokens; speaking them produces duplicated/garbled audio.
            for token in batch where token.kind == .translation && token.isFinal && !token.text.isEmpty {
                await ttsClient?.sendText(token.text)
            }
        case .finished:
            // Graceful close (idle timeout or server-side rotation). Reconnect
            // without consuming the failure budget — these aren't errors.
            guard status == .running, let apiKey = apiKeyCache else { return }
            logger.logInfo("STT stream ended mid-session - reconnecting")
            startSTT(apiKey: apiKey)
        case .failed(let message):
            await handleSTTFailure(message: message)
        }
    }

    private func handleSTTFailure(message: String) async {
        guard status == .running, let apiKey = apiKeyCache else {
            await fail(LiveTranslationError.webSocketFailure(message))
            return
        }

        sttFailureRetries += 1
        if sttFailureRetries > maxSTTFailureRetries {
            logger.logError("STT failed \(sttFailureRetries) times - giving up: \(message)")
            await fail(LiveTranslationError.webSocketFailure(message))
            return
        }

        // Exponential-ish backoff: 1s, 2s, 4s. Caps the worst-case spin rate
        // so a persistent failure (revoked key, server outage) doesn't hammer
        // Soniox or burn the device battery.
        let backoffSeconds = pow(2.0, Double(sttFailureRetries - 1))
        logger.logInfo("STT failed mid-session - reconnect attempt \(sttFailureRetries)/\(maxSTTFailureRetries) in \(backoffSeconds)s: \(message)")

        try? await Task.sleep(for: .seconds(backoffSeconds))
        guard status == .running else { return }
        startSTT(apiKey: apiKey)
    }

    private func handleTTSEvent(_ event: SonioxRealtimeTTSClient.Event) async {
        switch event {
        case .audio(let data):
            // Successful audio receipt = healthy connection; reset budget.
            ttsFailureRetries = 0
            audio.enqueuePlayback(data)
        case .finished:
            // Graceful close (Soniox auto-terminates after ~2 minutes). Reopen
            // without consuming the failure budget.
            guard status == .running, config.ttsEnabled else { return }
            logger.logInfo("TTS stream ended mid-session - reconnecting")
            await reopenTTSStream()
        case .failed(let message):
            await handleTTSFailure(message: message)
        }
    }

    private func handleTTSFailure(message: String) async {
        guard status == .running, config.ttsEnabled else {
            logger.logError("TTS stream failed (not running): \(message)")
            return
        }

        ttsFailureRetries += 1
        if ttsFailureRetries > maxTTSFailureRetries {
            logger.logError("TTS failed \(ttsFailureRetries) times - giving up: \(message)")
            // Tear down TTS only; keep STT/transcript running so the user
            // still sees text even though playback is gone.
            await closeTTSStream()
            return
        }

        let backoffSeconds = pow(2.0, Double(ttsFailureRetries - 1))
        logger.logInfo("TTS failed mid-session - reconnect attempt \(ttsFailureRetries)/\(maxTTSFailureRetries) in \(backoffSeconds)s: \(message)")

        try? await Task.sleep(for: .seconds(backoffSeconds))
        guard status == .running, config.ttsEnabled else { return }
        await reopenTTSStream()
    }

    private func reopenTTSStream() async {
        // Don't self-cancel ttsTask here; the OLD task's stream is finished
        // by disconnect() below and its for-await loop exits naturally on
        // the next iteration. openTTSStream will overwrite the ttsTask
        // reference with the new task.
        await ttsClient?.disconnect()
        ttsClient = nil

        guard status == .running, config.ttsEnabled else { return }
        guard let apiKey = KeychainService.shared.getString(forKey: "sonioxAPIKey"),
              !apiKey.isEmpty else { return }
        await openTTSStream(apiKey: apiKey)
    }

    private func appendTokens(_ batch: [LiveTranslationToken]) {
        // Split the batch by stream (original vs translation) and merge each
        // into its respective list. We split first so a response that updates
        // only one side doesn't disturb the other side's non-final tail.
        var originalBatch: [LiveTranslationToken] = []
        var translationBatch: [LiveTranslationToken] = []
        for token in batch {
            switch token.kind {
            case .original: originalBatch.append(token)
            case .translation: translationBatch.append(token)
            }
        }
        mergeBatch(originalBatch, into: &originalTokens)
        mergeBatch(translationBatch, into: &translatedTokens)
    }

    private func mergeBatch(_ batch: [LiveTranslationToken], into list: inout [LiveTranslationToken]) {
        guard !batch.isEmpty else { return }
        // Per Soniox protocol: non-final tokens in each response are a full
        // replacement set, so drop ALL trailing non-finals before appending
        // the new batch (which may itself contain finals followed by a new
        // non-final tail). Final tokens already in the list are committed
        // forever and stay put.
        while let last = list.last, !last.isFinal {
            list.removeLast()
        }
        list.append(contentsOf: batch)
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
        // A manual toggle is a fresh user intent — give it a fresh retry
        // budget so a previous run that hit the TTS retry cap doesn't make
        // the very next failure give up immediately.
        ttsFailureRetries = 0

        Task { [weak self] in
            guard let self else { return }
            if self.config.ttsEnabled {
                guard let apiKey = KeychainService.shared.getString(forKey: "sonioxAPIKey"),
                      !apiKey.isEmpty else { return }
                await self.openTTSStream(apiKey: apiKey)
            } else {
                await self.closeTTSStream()
            }
        }
    }

    private func closeTTSStream() async {
        await ttsClient?.disconnect()
        ttsClient = nil
        ttsTask?.cancel()
        ttsTask = nil
    }

    private func teardown() async {
        logger.logInfo("teardown: removing interruption observer")
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }

        logger.logInfo("teardown: cancelling tasks")
        captureTask?.cancel()
        captureTask = nil
        sttTask?.cancel()
        sttTask = nil
        ttsTask?.cancel()
        ttsTask = nil

        logger.logInfo("teardown: finalizing STT")
        await sttClient.finalizeAudio()
        logger.logInfo("teardown: disconnecting STT")
        await sttClient.disconnect()
        logger.logInfo("teardown: disconnecting TTS")
        await ttsClient?.disconnect()
        ttsClient = nil
        apiKeyCache = nil

        logger.logInfo("teardown: stopping audio")
        await audio.stop()
        logger.logInfo("teardown: complete")
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
            // Outer [weak self] is necessary even though the inner Task uses
            // [weak self]: otherwise the inner reference makes the outer
            // closure capture self strongly, creating a retain cycle with
            // interruptionObserver.
            guard self != nil else { return }
            guard let info = notification.userInfo,
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
        if oldValue.ttsVoice != config.ttsVoice,
           let voice = LiveTranslationVoice(rawValue: config.ttsVoice) {
            LiveTranslationPreferences.ttsVoice = voice
        }
    }

    private func renderText(from tokens: [LiveTranslationToken]) -> String {
        tokens
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
