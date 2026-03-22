//
//  TextDocumentProxyReader.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Reads text from a host app's text field via `UITextDocumentProxy`.
///
/// Two modes:
/// - **Selected text**: Returns `selectedText` directly — most reliable.
/// - **Text before cursor**: Returns `documentContextBeforeInput` — the chunk
///   of text before the current cursor position. The host app decides how much
///   text to return (typically a large chunk, but varies by app).
@MainActor
final class TextDocumentProxyReader {

    enum ReadResult {
        /// User explicitly selected text.
        case selectedText(String)
        /// Text before cursor (no explicit selection).
        case textBeforeCursor(String)
        /// No text available.
        case empty
    }

    /// Reads text from the host text field.
    ///
    /// If text is selected, returns the selection. Otherwise, returns whatever
    /// `documentContextBeforeInput` provides at the current cursor position.
    static func readText(from proxy: UITextDocumentProxy) -> ReadResult {
        // Prefer explicit selection
        if let selected = proxy.selectedText, !selected.isEmpty {
            return .selectedText(selected)
        }

        // Fall back to text before cursor
        if let before = proxy.documentContextBeforeInput, !before.isEmpty {
            return .textBeforeCursor(before)
        }

        return .empty
    }
}
