//
//  KeyboardTextProcessor.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit
import os

/// Orchestrates the text processing pipeline from the keyboard extension:
/// 1. Read selected text from host text field via `UITextDocumentProxy`
/// 2. Send to main app for AI processing via `AppGroupCoordinator`
/// 3. Wait for result
/// 4. Replace the selection with the processed text
@MainActor
final class KeyboardTextProcessor {

    private let logger = Logger(category: .keyboardExtension)
    private var currentTask: Task<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?
    private var isProcessing = false

    /// Processes selected text in the host text field using the specified mode.
    ///
    /// The user must select text before tapping a mode. If no text is selected,
    /// an error is shown.
    func processText(
        proxy: UITextDocumentProxy,
        mode: VivaMode,
        dictationState: KeyboardDictationState
    ) {
        // Prevent double invocation
        guard !isProcessing else {
            logger.logInfo("📝 [TextProcessor] Ignoring duplicate invocation — already processing")
            print("📝 [TextProcessor] Ignoring duplicate invocation — already processing")
            return
        }

        // Cancel any stale state
        cancel()

        isProcessing = true
        currentTask = Task {
            defer { isProcessing = false }
            do {
                try await performProcessing(proxy: proxy, mode: mode, dictationState: dictationState)
            } catch is CancellationError {
                dictationState.textProcessingPhase = .idle
            } catch {
                dictationState.textProcessingPhase = .error(error.localizedDescription)
                autoDismissError(dictationState: dictationState)
            }
        }
    }

    /// Cancels the current text processing operation.
    func cancel() {
        resultContinuation?.resume(throwing: CancellationError())
        resultContinuation = nil
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
    }

    private func performProcessing(
        proxy: UITextDocumentProxy,
        mode: VivaMode,
        dictationState: KeyboardDictationState
    ) async throws {
        // Phase 1: Read selected text
        let readResult = TextDocumentProxyReader.readText(from: proxy)

        let text: String
        switch readResult {
        case .selectedText(let t):
            text = t
            logger.logInfo("📝 [TextProcessor] Selected text read (\(t.count) chars): \(t)")
            print("📝 [TextProcessor] Selected text read (\(t.count) chars): \(t)")
        case .noSelection:
            logger.logInfo("📝 [TextProcessor] No text selected")
            print("📝 [TextProcessor] No text selected")
            dictationState.textProcessingPhase = .error("Select text to process")
            autoDismissError(dictationState: dictationState)
            return
        }

        try Task.checkCancellation()

        // Phase 2: Send to main app
        dictationState.textProcessingPhase = .sendingToApp
        logger.logInfo("📝 [TextProcessor] Sending to AI with mode: \(mode.name), text: \(text)")
        print("📝 [TextProcessor] Sending to AI with mode: \(mode.name), text: \(text)")

        let processedText: String = try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation

            dictationState.onTextProcessingResult = { [weak self] result in
                guard !result.isEmpty else {
                    print("📝 [TextProcessor] Ignoring empty result from callback")
                    return
                }
                self?.resultContinuation?.resume(returning: result)
                self?.resultContinuation = nil
            }

            dictationState.onTextProcessingError = { [weak self] message in
                self?.resultContinuation?.resume(throwing: TextProcessingError.processingFailed(message))
                self?.resultContinuation = nil
            }

            AppGroupCoordinator.shared.requestTextProcessing(text: text, modeName: mode.name)
            dictationState.textProcessingPhase = .waitingForResult(modeName: mode.name)
        }

        try Task.checkCancellation()

        // Phase 3: Replace selected text
        logger.logInfo("📝 [TextProcessor] AI result received (\(processedText.count) chars): \(processedText)")
        print("📝 [TextProcessor] AI result received (\(processedText.count) chars): \(processedText)")

        logger.logInfo("📝 [TextProcessor] Pasting result into host app")
        print("📝 [TextProcessor] Pasting result into host app: \(processedText)")
        TextDocumentProxyWriter.replaceSelectedText(in: proxy, with: processedText)

        // Phase 4: Done
        dictationState.textProcessingPhase = .completed

        try? await Task.sleep(for: .seconds(1))
        if dictationState.textProcessingPhase == .completed {
            dictationState.textProcessingPhase = .idle
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
