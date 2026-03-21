//
//  KeyboardTextProcessor.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Orchestrates the text processing pipeline from the keyboard extension:
/// 1. Read selected text from host text field via `UITextDocumentProxy`
/// 2. Send to main app for AI processing via `AppGroupCoordinator`
/// 3. Wait for result
/// 4. Replace the selection with the processed text
@MainActor
final class KeyboardTextProcessor {

    private var currentTask: Task<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?

    /// Processes selected text in the host text field using the specified mode.
    ///
    /// The user must select text before tapping a mode. If no text is selected,
    /// an error is shown.
    func processText(
        proxy: UITextDocumentProxy,
        mode: VivaMode,
        dictationState: KeyboardDictationState
    ) {
        // Cancel any in-progress processing
        cancel()

        currentTask = Task {
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
        case .noSelection:
            dictationState.textProcessingPhase = .error("Select text to process")
            autoDismissError(dictationState: dictationState)
            return
        }

        try Task.checkCancellation()

        // Phase 2: Send to main app
        dictationState.textProcessingPhase = .sendingToApp

        let processedText: String = try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation

            dictationState.onTextProcessingResult = { [weak self] result in
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
