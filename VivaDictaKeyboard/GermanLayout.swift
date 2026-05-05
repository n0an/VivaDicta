//
//  GermanLayout.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.05.04
//

import KeyboardKit

/// Rewrites the letter rows of a `KeyboardLayout` to QWERTZ (German).
///
/// Same template-copy approach as `AzertyLayout` and `RussianLayout`.
///
/// QWERTZ mapping (iPhone, matches Apple's German layout):
///   Row 0: q w e r t z u i o p ü  (11)
///   Row 1: a s d f g h j k l ö ä  (11)
///   Row 2: y x c v b n m          (7)
///
/// Row 2 stays at QWERTY's 7 letters, so shift/backspace keep their normal
/// widths (no need for the row-2 resize trick used in `RussianLayout`).
/// `ß` is reached via long-press on `s` (see `GermanCallouts`).
enum GermanLayout {

    private static let iPhoneRows: [[String]] = [
        ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
        ["y", "x", "c", "v", "b", "n", "m"]
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

/// Long-press callout alternates for German.
///
/// `s` -> `ß` is the only essential one (since ß has no dedicated key on
/// iPhone). Vowel accents (à, á, etc.) are added for typing French/Italian
/// loanwords. We omit ä/ö/ü from the a/o/u callouts because those umlauts
/// already have dedicated keys on the QWERTZ rows.
enum GermanCallouts {

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
        "a": "àáâãåæ",
        "c": "ç",
        "e": "éèêë",
        "i": "íìîï",
        "n": "ñ",
        "o": "óòôõœø",
        "s": "ß",
        "u": "úùûū",
        "y": "ÿ"
    ]
}
