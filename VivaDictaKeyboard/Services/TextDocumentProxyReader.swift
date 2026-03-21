//
//  TextDocumentProxyReader.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import UIKit

/// Reads text from a host app's text field via `UITextDocumentProxy`.
///
/// Handles two scenarios:
/// - **Selected text**: Returns `selectedText` directly from the proxy.
/// - **Full text**: Navigates through the document using `adjustTextPosition(byCharacterOffset:)`
///   to read all text in chunks (since `documentContextBeforeInput` is truncated by host apps).
///
/// The navigation is visible to the user as the cursor "jumping" through lines — this is expected
/// behavior, matching how apps like Spokenly read text from the host text field.
@MainActor
final class TextDocumentProxyReader {

    enum ReadResult {
        case selectedText(String)
        case fullText(String)
        case empty
    }

    /// Maximum number of characters to read to avoid memory issues in the keyboard extension.
    private static let maxCharacterLimit = 50_000

    /// Delay between cursor movements to allow the proxy to update its context.
    private static let cursorMoveDelay: Duration = .milliseconds(100)

    /// Reads text from the host text field.
    ///
    /// If text is selected, returns just the selection. Otherwise, navigates through
    /// the entire document to collect all text.
    static func readText(from proxy: UITextDocumentProxy) async -> ReadResult {
        // Check for selected text first — simplest path
        if let selected = proxy.selectedText, !selected.isEmpty {
            return .selectedText(selected)
        }

        // Read full text by navigating through the document
        let fullText = await readFullText(from: proxy)

        if fullText.isEmpty {
            return .empty
        }

        return .fullText(fullText)
    }

    /// Reads all text from the document by navigating with cursor movements.
    ///
    /// Algorithm (matches observed Spokenly behavior):
    /// 1. Read `documentContextBeforeInput` at current position
    /// 2. Move cursor backward, read again — repeat until reaching document start
    /// 3. From the start, move cursor forward reading `documentContextAfterInput` — repeat until reaching document end
    /// 4. Combine all collected text
    private static func readFullText(from proxy: UITextDocumentProxy) async -> String {
        // Phase 1: Read text before cursor (navigate backward)
        let textBeforeCursor = await readBackward(from: proxy)

        // Phase 2: Read text after original cursor position
        // First, return to original position by moving forward past all the text we just read
        if !textBeforeCursor.isEmpty {
            proxy.adjustTextPosition(byCharacterOffset: textBeforeCursor.count)
            try? await Task.sleep(for: cursorMoveDelay)
        }

        let textAfterCursor = await readForward(from: proxy)

        return textBeforeCursor + textAfterCursor
    }

    /// Reads all text before the cursor by navigating backward through the document.
    ///
    /// Returns the cursor to the beginning of the document when done.
    private static func readBackward(from proxy: UITextDocumentProxy) async -> String {
        var chunks: [String] = []
        var totalCharsRead = 0
        var previousContext: String?

        while totalCharsRead < maxCharacterLimit {
            guard let context = proxy.documentContextBeforeInput, !context.isEmpty else {
                break
            }

            // Detect if we're stuck (same context returned twice = we've reached the boundary)
            if context == previousContext {
                break
            }
            previousContext = context

            chunks.insert(context, at: 0)
            totalCharsRead += context.count

            // Move cursor backward by the length of what we just read
            proxy.adjustTextPosition(byCharacterOffset: -context.count)
            try? await Task.sleep(for: cursorMoveDelay)
        }

        // Deduplicate overlapping chunks.
        // When moving backward, the proxy may return overlapping text between reads.
        // Each chunk is the full `documentContextBeforeInput` at that cursor position,
        // so consecutive chunks can overlap: chunk[i] may end with the beginning of chunk[i+1].
        return deduplicateChunks(chunks)
    }

    /// Reads all text after the cursor by navigating forward through the document.
    ///
    /// Returns the cursor to the end of the document when done.
    private static func readForward(from proxy: UITextDocumentProxy) async -> String {
        var chunks: [String] = []
        var totalCharsRead = 0
        var previousContext: String?

        while totalCharsRead < maxCharacterLimit {
            guard let context = proxy.documentContextAfterInput, !context.isEmpty else {
                break
            }

            if context == previousContext {
                break
            }
            previousContext = context

            chunks.append(context)
            totalCharsRead += context.count

            // Move cursor forward by the length of what we just read
            proxy.adjustTextPosition(byCharacterOffset: context.count)
            try? await Task.sleep(for: cursorMoveDelay)
        }

        return deduplicateChunks(chunks)
    }

    /// Deduplicates overlapping chunks that result from reading via cursor navigation.
    ///
    /// When reading backward, `documentContextBeforeInput` at position N may overlap with
    /// the text read at position N+1. For example:
    /// - At position 100: "...text before cursor" (50 chars)
    /// - Move back 50, at position 50: "earlier text...text bef" (50 chars, overlapping)
    ///
    /// This method detects and removes overlaps between consecutive chunks.
    private static func deduplicateChunks(_ chunks: [String]) -> String {
        guard !chunks.isEmpty else { return "" }
        guard chunks.count > 1 else { return chunks[0] }

        var result = chunks[0]

        for i in 1..<chunks.count {
            let chunk = chunks[i]
            let overlap = findOverlap(between: result, and: chunk)
            if overlap > 0 {
                result += chunk.dropFirst(overlap)
            } else {
                result += chunk
            }
        }

        return result
    }

    /// Finds the number of overlapping characters where the end of `first` matches
    /// the beginning of `second`.
    private static func findOverlap(between first: String, and second: String) -> Int {
        let maxOverlap = min(first.count, second.count)
        guard maxOverlap > 0 else { return 0 }

        // Check from longest possible overlap down to 1
        for length in stride(from: maxOverlap, through: 1, by: -1) {
            let suffix = first.suffix(length)
            let prefix = second.prefix(length)
            if suffix == prefix {
                return length
            }
        }

        return 0
    }
}
