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

    /// Replaces the currently selected text with the processed text.
    /// When text is selected, `insertText(_:)` automatically replaces the selection.
    static func replaceSelectedText(in proxy: UITextDocumentProxy, with text: String) {
        proxy.insertText(text)
    }

    /// Deletes `charCount` characters before the cursor, then inserts the replacement.
    static func replaceTextBeforeCursor(in proxy: UITextDocumentProxy, charCount: Int, with text: String) {
        for _ in 0..<charCount {
            proxy.deleteBackward()
        }
        proxy.insertText(text)
    }
}
