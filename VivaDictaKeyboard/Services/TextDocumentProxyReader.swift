//
//  TextDocumentProxyReader.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Reads selected text from a host app's text field via `UITextDocumentProxy`.
///
/// Only supports reading explicitly selected text. Full-document reading via cursor
/// navigation is unreliable across host apps (truncation behavior varies), so users
/// must select the text they want to process.
@MainActor
final class TextDocumentProxyReader {

    enum ReadResult {
        case selectedText(String)
        case noSelection
    }

    /// Reads the currently selected text from the host text field.
    static func readText(from proxy: UITextDocumentProxy) -> ReadResult {
        if let selected = proxy.selectedText, !selected.isEmpty {
            return .selectedText(selected)
        }
        return .noSelection
    }
}
