//
//  AzertyLayout.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.04.21
//

import KeyboardKit

/// Rewrites the letter rows of a `KeyboardLayout` to AZERTY.
///
/// KeyboardKit 10 ships `KeyboardLayout.InputSet.azerty` but it's Pro-locked
/// (the getter throws without a Pro license). We instead take the standard
/// QWERTY layout - which gives us the correct bottom row, shift, backspace,
/// and device-appropriate key widths - and swap only the character actions
/// in the letter rows.
///
/// AZERTY mapping (iPhone):
///   Row 0: a z e r t y u i o p  (10 - same count as QWERTY)
///   Row 1: q s d f g h j k l m  (10 - QWERTY has 9, extra `m`)
///   Row 2: w x c v b n          (6  - QWERTY has 7, no `m`)
///
/// The `m` moves from the bottom row up to the middle row, matching
/// Apple's and Windows' French AZERTY conventions.
enum AzertyLayout {

    /// iPhone letter rows for AZERTY.
    private static let iPhoneRows: [[String]] = [
        ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
        ["w", "x", "c", "v", "b", "n"]
    ]

    /// Returns a new `KeyboardLayout` with its letter rows rewritten to AZERTY.
    ///
    /// Non-character items (shift, backspace, space, return, 123, globe, etc.)
    /// are left in place with their original sizes and insets. Only items
    /// whose action is `.character(_)` are replaced.
    ///
    /// If the layout doesn't match the expected shape (3 letter rows on iPhone),
    /// the original layout is returned unchanged rather than producing a broken
    /// keyboard.
    static func rewrite(_ layout: KeyboardLayout) -> KeyboardLayout {
        var result = layout
        let letterRowIndices = result.itemRows.indices.filter { rowHasCharacters(result.itemRows[$0]) }

        guard letterRowIndices.count == iPhoneRows.count else {
            // iPad or an unexpected shape - skip rather than produce a broken row.
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
    /// Non-character items (shift, backspace, etc.) stay in place.
    ///
    /// The case of each existing `.character(c)` is mirrored onto the replacement
    /// so AZERTY follows the standard layout's shift state. KeyboardKit's standard
    /// layout rebuilds character actions as `.character("A")` or `.character("a")`
    /// based on `KeyboardContext.keyboardCase`; if we always emitted lowercase,
    /// shifted AZERTY buttons would display and insert lowercase letters.
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

extension KeyboardLayout {
    /// Returns the layout rewritten to AZERTY if `style` is `.azerty`,
    /// otherwise returns the layout unchanged.
    func applying(_ style: KeyboardLayoutStyle) -> KeyboardLayout {
        switch style {
        case .qwerty: self
        case .azerty: AzertyLayout.rewrite(self)
        }
    }
}

/// Long-press callout alternates for French AZERTY.
///
/// KeyboardKit Pro ships per-locale callouts (`Callouts.Actions.french`); these
/// are Pro-locked. We supply our own French table and register it via the
/// `.keyboardCalloutActions` view modifier on the `KeyboardView`.
///
/// Uppercase inputs (when shift is active) receive uppercased alternates so
/// long-pressing `E` shows `É È Ê Ë` rather than the lowercase set.
enum AzertyCallouts {

    /// A callout builder that returns French alternates for known letters
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

    /// Lowercase-keyed character → alternates mapping for French AZERTY.
    /// Ordering follows iOS French keyboard convention (most common first).
    private static let byCharacter: [String: String] = [
        "a": "àâæ",
        "c": "ç",
        "e": "éèêëę",
        "i": "îïì",
        "n": "ñ",
        "o": "ôœö",
        "u": "ûùü",
        "y": "ÿ"
    ]
}
