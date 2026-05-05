//
//  SpanishLayout.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.05.04
//

import KeyboardKit

/// Rewrites the letter rows of a `KeyboardLayout` to Spanish (QWERTY + ñ).
///
/// Same template-copy approach as the other layout rewriters.
///
/// Spanish mapping (iPhone, matches Apple's Spanish layout):
///   Row 0: q w e r t y u i o p  (10)
///   Row 1: a s d f g h j k l ñ  (10, one more than English)
///   Row 2: z x c v b n m        (7)
///
/// Row 1 picks up `ñ` as a dedicated key. Row 0 stays at QWERTY's 10 letters,
/// row 2 stays at QWERTY's 7 letters, so shift/backspace keep their normal
/// widths.
///
/// Vowel accents (á, é, í, ó, ú) are reached via long-press, see
/// `SpanishCallouts`.
enum SpanishLayout {

    private static let iPhoneRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    static func rewrite(_ layout: KeyboardLayout) -> KeyboardLayout {
        var result = layout
        let letterRowIndices = result.itemRows.indices.filter { rowHasCharacters(result.itemRows[$0]) }

        guard letterRowIndices.count == iPhoneRows.count else {
            return layout
        }

        for (mappingIndex, rowIndex) in letterRowIndices.enumerated() {
            result.itemRows[rowIndex] = rewriteLetters(
                in: result.itemRows[rowIndex],
                to: iPhoneRows[mappingIndex]
            )
        }

        return result
    }

    private static func rowHasCharacters(_ row: [KeyboardLayout.Item]) -> Bool {
        row.contains { item in
            if case .character = item.action { return true }
            return false
        }
    }

    private static func rewriteLetters(
        in row: [KeyboardLayout.Item],
        to chars: [String]
    ) -> [KeyboardLayout.Item] {
        var charIndices: [Int] = []
        var isUppercaseInRow = false
        for (index, item) in row.enumerated() {
            guard case .character(let existing) = item.action else { continue }
            charIndices.append(index)
            if !isUppercaseInRow, existing.first?.isUppercase == true {
                isUppercaseInRow = true
            }
        }

        guard let templateIndex = charIndices.first else { return row }
        let template = row[templateIndex]

        var result = row
        for index in charIndices.reversed() {
            result.remove(at: index)
        }

        for (offset, char) in chars.enumerated() {
            let cased = isUppercaseInRow ? char.uppercased() : char
            let item = KeyboardLayout.Item(
                action: .character(cased),
                size: template.size,
                alignment: template.alignment,
                edgeInsets: template.edgeInsets
            )
            result.insert(item, at: templateIndex + offset)
        }

        return result
    }
}

/// Long-press callout alternates for Spanish.
///
/// Standard accented vowels plus `¿` on `?` and `¡` on `!` for the inverted
/// punctuation. (Punctuation alternates are handled when the user is on the
/// numeric/symbolic keyboard - they pass through here unchanged.)
enum SpanishCallouts {

    static let actionsBuilder: Callouts.ActionsBuilder = { params in
        guard case .character(let char) = params.action else {
            return params.standardActions()
        }
        let lower = char.lowercased()
        guard let alternates = byCharacter[lower] else {
            return params.standardActions()
        }
        let isUppercase = char != lower
        return alternates.map { alternate in
            let value = isUppercase ? String(alternate).uppercased() : String(alternate)
            return .character(value)
        }
    }

    private static let byCharacter: [String: String] = [
        "a": "áàâäãå",
        "c": "ç",
        "e": "éèêë",
        "i": "íìîï",
        "o": "óòôöõ",
        "u": "úùûü"
    ]
}
