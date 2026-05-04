//
//  RussianLayout.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.05.04
//

import KeyboardKit

/// Rewrites the letter rows of a `KeyboardLayout` to ЙЦУКЕН (Russian).
///
/// Same template-copy approach as `AzertyLayout`: take the standard QWERTY
/// layout (which gives us shift, backspace, the bottom row, and device-correct
/// key sizes), then swap only the items whose action is `.character(_)`.
///
/// ЙЦУКЕН mapping (iPhone):
///   Row 0: й ц у к е н г ш щ з х  (11)
///   Row 1: ф ы в а п р о л д ж э  (11)
///   Row 2: я ч с м и т ь б ю      (9)
///
/// Russian has 33 letters. ё is reached via long-press on `е` on the system
/// keyboard - omitted here per spec. ъ is dropped from row 0 (Apple has it
/// there) because it's accessible via long-press on `ь`, and dropping it
/// keeps each row's keys wider and easier to hit on iPhone widths.
enum RussianLayout {

    /// iPhone letter rows for ЙЦУКЕН.
    private static let iPhoneRows: [[String]] = [
        ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х"],
        ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
        ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"]
    ]

    /// Returns a new `KeyboardLayout` with its letter rows rewritten to ЙЦУКЕН.
    ///
    /// Non-character items (shift, backspace, space, return, 123, globe) are
    /// left in place. Each row's character items are removed and replaced with
    /// the Russian letters at the same insertion point, copying the original
    /// item's `.input` size - which is proportional, so a row with 12 letters
    /// just produces narrower keys, leaving shift/backspace at their fixed widths.
    ///
    /// If the layout doesn't match the expected shape (3 letter rows on iPhone),
    /// the original layout is returned unchanged rather than producing a broken
    /// keyboard.
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

    /// Replaces the character items in `row` with new character items for `chars`.
    /// Mirrors the case of the existing items so shift state survives the swap.
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

/// Long-press callout alternates for Russian.
///
/// Only `ь` -> `ъ` for now. ё is intentionally not included on `е` (per request);
/// users who need ё can rely on autocorrect or paste it.
enum RussianCallouts {

    /// A callout builder that returns Russian alternates for known letters
    /// and falls back to KeyboardKit's standard actions for everything else.
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

    /// Lowercase-keyed character -> alternates mapping for Russian.
    private static let byCharacter: [String: String] = [
        "ь": "ъ"
    ]
}
