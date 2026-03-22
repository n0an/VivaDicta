//
//  TextDocumentProxyWriter.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Replaces text in a host app's text field via `UITextDocumentProxy`.
@MainActor
final class TextDocumentProxyWriter {

    /// Delay between delete batches to let the proxy update.
    private static let deleteBatchDelay: Duration = .milliseconds(100)

    /// Replaces the currently selected text with the processed text.
    /// When text is selected, `insertText(_:)` automatically replaces the selection.
    static func replaceSelectedText(in proxy: UITextDocumentProxy, with text: String) {
        proxy.insertText(text)
    }

    /// Deletes `charCount` characters before the cursor, then inserts the replacement.
    ///
    /// Used when no text is selected — deletes the chunk that was read via
    /// `documentContextBeforeInput`, then inserts the AI-processed result.
    static func replaceTextBeforeCursor(in proxy: UITextDocumentProxy, charCount: Int, with text: String) async {
        // Delete the original text
        var remaining = charCount
        while remaining > 0 {
            let batch = min(remaining, 100)
            for _ in 0..<batch {
                proxy.deleteBackward()
            }
            remaining -= batch
            if remaining > 0 {
                try? await Task.sleep(for: deleteBatchDelay)
            }
        }

        // Insert the processed text
        proxy.insertText(text)
    }
}
