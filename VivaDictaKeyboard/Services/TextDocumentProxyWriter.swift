//
//  TextDocumentProxyWriter.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Replaces text in a host app's text field via `UITextDocumentProxy`.
///
/// Two modes:
/// - **Replace selection**: Simply inserts text, which replaces the current selection.
/// - **Replace all text**: Navigates to end, deletes everything via `deleteBackward()`,
///   then inserts the new text. The deletion is visible as rapid character removal.
@MainActor
final class TextDocumentProxyWriter {

    /// Delay between cursor movements during navigation.
    private static let cursorMoveDelay: Duration = .milliseconds(100)

    /// Delay between delete batches to let the proxy update.
    private static let deleteBatchDelay: Duration = .milliseconds(10)

    /// Replaces the currently selected text with the processed text.
    ///
    /// When text is selected, `insertText(_:)` automatically replaces the selection.
    static func replaceSelectedText(in proxy: UITextDocumentProxy, with text: String) {
        proxy.insertText(text)
    }

    /// Replaces all text in the text field with the processed text.
    ///
    /// Algorithm (matches observed Spokenly behavior):
    /// 1. Navigate to the end of the document
    /// 2. Delete all text using `deleteBackward()` in rapid batches
    /// 3. Insert the new text at once
    static func replaceAllText(in proxy: UITextDocumentProxy, with text: String) async {
        // Step 1: Navigate to end of document
        await navigateToEnd(proxy: proxy)

        // Step 2: Delete all text from end to start
        await deleteAllText(proxy: proxy)

        // Step 3: Insert the processed text
        proxy.insertText(text)
    }

    /// Moves the cursor to the end of the document.
    private static func navigateToEnd(proxy: UITextDocumentProxy) async {
        // Keep moving forward until there's no text after the cursor
        while let after = proxy.documentContextAfterInput, !after.isEmpty {
            proxy.adjustTextPosition(byCharacterOffset: after.count)
            try? await Task.sleep(for: cursorMoveDelay)
        }
    }

    /// Deletes all text in the document by calling `deleteBackward()` repeatedly.
    ///
    /// Works in batches: reads how much text is before the cursor, deletes that many
    /// characters, then checks again. This handles cases where the proxy only reports
    /// a limited window of text.
    private static func deleteAllText(proxy: UITextDocumentProxy) async {
        while let before = proxy.documentContextBeforeInput, !before.isEmpty {
            // Delete all characters reported before the cursor
            for _ in 0..<before.count {
                proxy.deleteBackward()
            }
            try? await Task.sleep(for: deleteBatchDelay)
        }
    }
}
