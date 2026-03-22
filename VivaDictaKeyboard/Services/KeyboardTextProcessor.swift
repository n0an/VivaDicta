//
//  KeyboardTextProcessor.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit
import os

/// Orchestrates the text processing pipeline from the keyboard extension:
/// 1. Read text from host text field via `UITextDocumentProxy`
///    (selected text, or text before cursor if nothing selected)
/// 2. Send to main app for AI processing via `AppGroupCoordinator`
/// 3. Wait for result
/// 4. Replace the original text with the processed result
@MainActor
final class KeyboardTextProcessor {

    private let logger = Logger(category: .keyboardExtension)
    private var currentTask: Task<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?
    private var isProcessing = false

    /// Processes text in the host text field using the specified mode.
    ///
    /// If text is selected, processes the selection. Otherwise, processes
    /// `documentContextBeforeInput` (text before cursor).
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
        // Phase 1: Read text
        let readResult = TextDocumentProxyReader.readText(from: proxy)

        let text: String
        let isSelection: Bool
        switch readResult {
        case .selectedText(let t):
            text = t
            isSelection = true
            logger.logInfo("📝 [TextProcessor] Selected text read (\(t.count) chars): \(t)")
            print("📝 [TextProcessor] Selected text read (\(t.count) chars): \(t)")
        case .textBeforeCursor(let t):
            text = t
            isSelection = false
            logger.logInfo("📝 [TextProcessor] Text before cursor read (\(t.count) chars): \(t)")
            print("📝 [TextProcessor] Text before cursor read (\(t.count) chars): \(t)")
        case .empty:
            logger.logInfo("📝 [TextProcessor] No text found")
            print("📝 [TextProcessor] No text found")
            dictationState.textProcessingPhase = .error("No text to process")
            autoDismissError(dictationState: dictationState)
            return
        }

        try Task.checkCancellation()

        // Phase 2: Send to main app
        dictationState.textProcessingPhase = .sendingToApp
        logger.logInfo("📝 [TextProcessor] Sending to AI with mode: \(mode.name), text (\(text.count) chars)")
        print("📝 [TextProcessor] Sending to AI with mode: \(mode.name), text (\(text.count) chars): \(text)")

        let processedText: String = try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation

            dictationState.onTextProcessingResult = { [weak self] result in
                if result.isEmpty {
                    print("📝 [TextProcessor] Received empty result — treating as error")
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

            AppGroupCoordinator.shared.requestTextProcessing(text: text, modeName: mode.name)
            dictationState.textProcessingPhase = .waitingForResult(modeName: mode.name)
        }

        try Task.checkCancellation()

        // Phase 3: Replace text
        logger.logInfo("📝 [TextProcessor] AI result received (\(processedText.count) chars): \(processedText)")
        print("📝 [TextProcessor] AI result received (\(processedText.count) chars): \(processedText)")

        if isSelection {
            logger.logInfo("📝 [TextProcessor] Replacing selected text")
            print("📝 [TextProcessor] Replacing selected text")
            TextDocumentProxyWriter.replaceSelectedText(in: proxy, with: processedText)
        } else {
            logger.logInfo("📝 [TextProcessor] Replacing \(text.count) chars before cursor")
            print("📝 [TextProcessor] Replacing \(text.count) chars before cursor")
            await TextDocumentProxyWriter.replaceTextBeforeCursor(in: proxy, charCount: text.count, with: processedText)
        }

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
