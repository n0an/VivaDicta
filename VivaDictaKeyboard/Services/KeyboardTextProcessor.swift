//
//  KeyboardTextProcessor.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit
import AppGroup
import os
import AICore

/// Orchestrates the text processing pipeline from the keyboard extension:
/// 1. Read text from host text field via `UITextDocumentProxy`
///    (selected text, or text before cursor if nothing selected)
/// 2. Send to main app for AI processing via `AppGroupCoordinator`
/// 3. Wait for result
/// 4. Replace the original text with the processed result
///
/// Two ways in, sharing steps 1, 3 and 4:
/// - ``processText(proxy:mode:presetId:dictationState:)`` applies a preset the
///   user tapped.
/// - ``processTextWithSpokenInstruction(proxy:mode:dictationState:)`` records an
///   ad-hoc spoken instruction first ("make this more formal") and applies that.
@MainActor
final class KeyboardTextProcessor {

    private let logger = Logger(category: .keyboardExtension)
    private var currentTask: Task<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?
    private var isProcessing = false
    /// True while the main app is recording a spoken instruction for us, so
    /// ``cancel()`` knows it also has to stop that recording.
    private var isRecordingInstruction = false

    /// Processes text in the host text field using the specified mode and optional preset.
    ///
    /// If text is selected, processes the selection. Otherwise, processes
    /// `documentContextBeforeInput` (text before cursor).
    func processText(
        proxy: UITextDocumentProxy,
        mode: VivaMode,
        presetId: String? = nil,
        dictationState: KeyboardDictationState
    ) {
        // Prevent double invocation
        guard !isProcessing else {
            logger.logInfo("📝 [TextProcessor] Ignoring duplicate invocation — already processing")
            return
        }

        // GPU-backed on-device LLMs (Gemma/LiteRT, MLX) run on the Metal GPU, which
        // iOS blocks while the app is backgrounded - and the keyboard always runs
        // with the main app backgrounded. The doomed round-trip would otherwise
        // hang or crash the app, so fail fast here with an actionable message.
        // CoreML models (ANE) are exempt - they DO work backgrounded. Apple FM
        // (out-of-process) and cloud providers also work from the keyboard.
        if mode.aiProvider == .local, !AIProvider.localModelRunsOnNeuralEngine(mode.aiModel) {
            logger.logInfo("📝 [TextProcessor] GPU on-device mode '\(mode.name)' unavailable from keyboard (GPU blocked in background)")
            HapticManager.error()
            dictationState.textProcessingPhase = .error("This on-device model runs on the GPU and needs the VivaDicta app open. Use a CoreML model, Apple Foundation Model, or a cloud model from the keyboard.")
            autoDismissError(dictationState: dictationState)
            return
        }

        // Cancel any stale state
        cancel()

        isProcessing = true
        currentTask = Task {
            defer { isProcessing = false }
            do {
                try await performProcessing(proxy: proxy, mode: mode, presetId: presetId, dictationState: dictationState)
            } catch is CancellationError {
                dictationState.textProcessingPhase = .idle
            } catch {
                HapticManager.error()
                dictationState.textProcessingPhase = .error(error.localizedDescription)
                autoDismissError(dictationState: dictationState)
            }
        }
    }

    /// Records a spoken instruction and applies it to the host text field.
    ///
    /// Same read/replace path as ``processText(proxy:mode:presetId:dictationState:)``;
    /// the instruction is dictated instead of tapped. The target text is captured
    /// and parked *before* recording starts, so what gets rewritten is what was
    /// selected when the user reached for the mic.
    func processTextWithSpokenInstruction(
        proxy: UITextDocumentProxy,
        mode: VivaMode,
        dictationState: KeyboardDictationState
    ) {
        guard !isProcessing else {
            logger.logInfo("🗣️ [TextProcessor] Ignoring duplicate invocation — already processing")
            return
        }

        guard dictationState.isSessionActive else {
            HapticManager.error()
            dictationState.textProcessingPhase = .error("Open VivaDicta to use voice instructions.")
            autoDismissError(dictationState: dictationState)
            return
        }

        guard let target = readTarget(from: proxy, dictationState: dictationState) else { return }

        cancel()

        isProcessing = true
        isRecordingInstruction = true
        currentTask = Task {
            defer {
                isProcessing = false
                isRecordingInstruction = false
            }
            do {
                dictationState.textProcessingPhase = .recordingInstruction
                HapticManager.mediumImpact()

                let processedText = try await awaitResult(dictationState: dictationState) {
                    AppGroupCoordinator.shared.requestVoiceInstructionRecording(
                        targetText: target.text,
                        modeName: mode.name
                    )
                }

                try Task.checkCancellation()
                replace(target: target, with: processedText, in: proxy, dictationState: dictationState)
            } catch is CancellationError {
                dictationState.textProcessingPhase = .idle
            } catch {
                HapticManager.error()
                dictationState.textProcessingPhase = .error(error.localizedDescription)
                autoDismissError(dictationState: dictationState)
            }
        }
    }

    /// Cancels the current text processing operation.
    func cancel() {
        if isRecordingInstruction {
            // The main app may be mid-recording, or may not have picked the
            // request up at all. Undo both, or the next ordinary dictation gets
            // mistaken for an instruction.
            AppGroupCoordinator.shared.requestCancelRecording()
            AppGroupCoordinator.shared.clearPendingVoiceInstruction()
            isRecordingInstruction = false
        }
        resultContinuation?.resume(throwing: CancellationError())
        resultContinuation = nil
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
    }

    private func performProcessing(
        proxy: UITextDocumentProxy,
        mode: VivaMode,
        presetId: String? = nil,
        dictationState: KeyboardDictationState
    ) async throws {
        // Phase 1: Read text
        guard let target = readTarget(from: proxy, dictationState: dictationState) else { return }

        try Task.checkCancellation()

        // Phase 2: Send to main app
        dictationState.textProcessingPhase = .sendingToApp
        logger.logInfo("📝 [TextProcessor] Sending to AI with mode: \(mode.name), preset: \(presetId ?? "nil"), text (\(target.text.count) chars): \(target.text)")

        let processedText = try await awaitResult(dictationState: dictationState) {
            AppGroupCoordinator.shared.requestTextProcessing(
                text: target.text,
                modeName: mode.name,
                presetId: presetId
            )
            dictationState.textProcessingPhase = .waitingForResult(modeName: mode.name)
        }

        try Task.checkCancellation()

        // Phases 3 and 4
        replace(target: target, with: processedText, in: proxy, dictationState: dictationState)
    }

    // MARK: - Shared Steps

    /// What the AI result will replace: the user's selection, or the chunk of
    /// text before the cursor when nothing is selected.
    private struct Target {
        let text: String
        let isSelection: Bool
    }

    /// Phase 1 - reads the text to rewrite, surfacing the empty case as an error.
    private func readTarget(
        from proxy: UITextDocumentProxy,
        dictationState: KeyboardDictationState
    ) -> Target? {
        switch TextDocumentProxyReader.readText(from: proxy) {
        case .selectedText(let text):
            logger.logInfo("📝 [TextProcessor] Selected text read (\(text.count) chars): \(text)")
            return Target(text: text, isSelection: true)
        case .textBeforeCursor(let text):
            logger.logInfo("📝 [TextProcessor] Text before cursor read (\(text.count) chars): \(text)")
            return Target(text: text, isSelection: false)
        case .empty:
            logger.logInfo("📝 [TextProcessor] No text found")
            dictationState.textProcessingPhase = .error("No text to process")
            autoDismissError(dictationState: dictationState)
            return nil
        }
    }

    /// Phase 2 - runs `request` and suspends until the main app answers on the
    /// text processing channel, or the keyboard session goes away.
    private func awaitResult(
        dictationState: KeyboardDictationState,
        request: @escaping () -> Void
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation

            dictationState.onTextProcessingResult = { [weak self] result in
                if result.isEmpty {
                    self?.logger.logInfo("📝 [TextProcessor] Received empty result — treating as error")
                    self?.resultContinuation?.resume(throwing: TextProcessingError.processingFailed("AI returned empty result"))
                } else {
                    self?.resultContinuation?.resume(returning: result)
                }
                self?.resultContinuation = nil
            }

            dictationState.onTextProcessingError = { [weak self] message in
                self?.resultContinuation?.resume(throwing: TextProcessingError.processingFailed(message))
                self?.resultContinuation = nil
            }

            // Session expiry = main app went away
            dictationState.onSessionExpired = { [weak self] in
                self?.logger.logInfo("📝 [TextProcessor] Session expired during text processing")
                self?.resultContinuation?.resume(throwing: TextProcessingError.processingFailed("Session expired. Open VivaDicta and try again."))
                self?.resultContinuation = nil
            }

            request()
        }
    }

    /// Phases 3 and 4 - writes the result back over the original text and settles the UI.
    private func replace(
        target: Target,
        with processedText: String,
        in proxy: UITextDocumentProxy,
        dictationState: KeyboardDictationState
    ) {
        logger.logInfo("📝 [TextProcessor] AI result received (\(processedText.count) chars): \(processedText)")

        if target.isSelection {
            logger.logInfo("📝 [TextProcessor] Replacing selected text")
            TextDocumentProxyWriter.replaceSelectedText(in: proxy, with: processedText)
        } else {
            logger.logInfo("📝 [TextProcessor] Replacing \(target.text.count) chars before cursor")
            TextDocumentProxyWriter.replaceTextBeforeCursor(in: proxy, charCount: target.text.count, with: processedText)
        }

        HapticManager.heartbeat()
        AppGroupCoordinator.shared.recordKeyboardSuccessfulUse()
        dictationState.textProcessingPhase = .completed

        Task {
            try? await Task.sleep(for: .seconds(1))
            if dictationState.textProcessingPhase == .completed {
                dictationState.textProcessingPhase = .idle
            }
        }
    }

    private func autoDismissError(dictationState: KeyboardDictationState) {
        Task {
            try? await Task.sleep(for: .seconds(5))
            if case .error = dictationState.textProcessingPhase {
                dictationState.textProcessingPhase = .idle
            }
        }
    }

    enum TextProcessingError: LocalizedError {
        case processingFailed(String)

        var errorDescription: String? {
            switch self {
            case .processingFailed(let message): message
            }
        }
    }
}
