//
//  TextDocumentProxyWriter.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Replaces selected text in a host app's text field via `UITextDocumentProxy`.
///
/// When text is selected, `insertText(_:)` automatically replaces the selection.
@MainActor
final class TextDocumentProxyWriter {

    /// Replaces the currently selected text with the processed text.
    static func replaceSelectedText(in proxy: UITextDocumentProxy, with text: String) {
        proxy.insertText(text)
    }
}
