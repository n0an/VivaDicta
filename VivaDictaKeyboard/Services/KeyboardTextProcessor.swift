//
//  KeyboardTextProcessor.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Orchestrates the full text processing pipeline from the keyboard extension:
/// 1. Read text from host text field via `UITextDocumentProxy`
/// 2. Send to main app for AI processing via `AppGroupCoordinator`
/// 3. Wait for result
/// 4. Replace text in the host text field
@MainActor
final class KeyboardTextProcessor {

    private var currentTask: Task<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?

    /// Processes text in the host text field using the specified preset.
    ///
    /// - Parameters:
    ///   - proxy: The text document proxy for the host text field.
    ///   - preset: The preset to use for AI processing.
    ///   - dictationState: The keyboard state to update with progress.
    func processText(
        proxy: UITextDocumentProxy,
        preset: Preset,
        dictationState: KeyboardDictationState
    ) {
        // Cancel any in-progress processing
        cancel()

        currentTask = Task {
            do {
                try await performProcessing(proxy: proxy, preset: preset, dictationState: dictationState)
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
        preset: Preset,
        dictationState: KeyboardDictationState
    ) async throws {
        // Phase 1: Read text from host text field
        dictationState.textProcessingPhase = .readingText
        try Task.checkCancellation()

        let readResult = await TextDocumentProxyReader.readText(from: proxy)

        let (text, wasSelected): (String, Bool)
        switch readResult {
        case .selectedText(let t):
            text = t
            wasSelected = true
        case .fullText(let t):
            text = t
            wasSelected = false
        case .empty:
            dictationState.textProcessingPhase = .error("No text found in the text field")
            autoDismissError(dictationState: dictationState)
            return
        }

        try Task.checkCancellation()

        // Phase 2: Send to main app
        dictationState.textProcessingPhase = .sendingToApp

        // Set up callbacks to receive result
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

            AppGroupCoordinator.shared.requestTextProcessing(text: text, presetId: preset.id)
            dictationState.textProcessingPhase = .waitingForResult(presetName: preset.name)
        }

        try Task.checkCancellation()

        // Phase 3: Replace text in host text field
        dictationState.textProcessingPhase = .replacing

        if wasSelected {
            TextDocumentProxyWriter.replaceSelectedText(in: proxy, with: processedText)
        } else {
            await TextDocumentProxyWriter.replaceAllText(in: proxy, with: processedText)
        }

        // Phase 4: Done
        dictationState.textProcessingPhase = .completed

        // Auto-return to idle after a brief moment
        try? await Task.sleep(for: .seconds(1))
        if dictationState.textProcessingPhase == .completed {
            dictationState.textProcessingPhase = .idle
            dictationState.isShowingRewritePresets = false
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
