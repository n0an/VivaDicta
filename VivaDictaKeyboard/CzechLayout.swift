//
//  CzechLayout.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.09.02
//

import KeyboardKit

/// Rewrites a `KeyboardLayout` to Czech QWERTZ.
///
/// Unlike `AzertyLayout`, `GermanLayout`, `SpanishLayout` and `RussianLayout`,
/// this one does not rebuild the letter rows from a character table. The Czech
/// layout is the English QWERTY layout with `y` and `z` swapped and nothing
/// else, so we take the standard layout as-is and swap those two keys in
/// place. Key counts (10/9/7), sizes, shift, backspace and space are therefore
/// bit-for-bit identical to English.
///
///   Row 0: q w e r t z u i o p  (10)
///   Row 1: a s d f g h j k l    (9)
///   Row 2: y x c v b n m        (7)
///
/// The swap covers KeyboardKit's `.characterMargin` items too. These are the
/// invisible keys that pad the ends of an iPhone letter row and type the
/// letter they sit next to, so a tap just past the edge key still hits it.
/// Row 2 starts with `.characterMargin("z")` between shift and the first
/// letter; left alone, a tap in that gap types `z` right beside the `y` key.
///
/// All Czech diacritics (á č ď é ě í ň ó ř š ť ú ů ý ž) are reached via
/// long-press — see `CzechCallouts`. No German umlauts appear on the keys.
enum CzechLayout {

    static func rewrite(_ layout: KeyboardLayout) -> KeyboardLayout {
        var result = layout

        for rowIndex in result.itemRows.indices {
            for itemIndex in result.itemRows[rowIndex].indices {
                switch result.itemRows[rowIndex][itemIndex].action {
                case .character(let char):
                    guard let swapped = swapped(char) else { continue }
                    result.itemRows[rowIndex][itemIndex].action = .character(swapped)
                case .characterMargin(let char):
                    guard let swapped = swapped(char) else { continue }
                    result.itemRows[rowIndex][itemIndex].action = .characterMargin(swapped)
                default:
                    continue
                }
            }
        }

        return result
    }

    /// The QWERTY -> QWERTZ swap, preserving letter case.
    private static func swapped(_ char: String) -> String? {
        switch char {
        case "y": "z"
        case "z": "y"
        case "Y": "Z"
        case "Z": "Y"
        default: nil
        }
    }
}

/// Long-press callout alternates for Czech.
///
/// Czech-only: every alternate here is a letter of the Czech alphabet, so the
/// callouts stay short and there is no foreign accent (à, œ, ß, …) to scroll
/// past. Uppercase is derived from the pressed key, so `C` long-presses to `Č`.
///
/// Letters with no Czech diacritic get *no* callout at all rather than falling
/// back to `standardActions()`, which would offer KeyboardKit's pan-European
/// set (ŵ, ġ, ħ, ķ, ł, …) — none of which exist in Czech. Non-letters do keep
/// their standard callouts, so quotes, punctuation and digits still work.
enum CzechCallouts {

    static let actionsBuilder: KeyboardCalloutActions.Builder = { params in
        guard case .character(let char) = params.action else {
            return params.standardActions()
        }
        let lower = char.lowercased()
        guard let alternates = byCharacter[lower] else {
            return lower.first?.isLetter == true ? [] : params.standardActions()
        }
        let isUppercase = char != lower
        return alternates.map { alternate in
            let value = isUppercase ? String(alternate).uppercased() : String(alternate)
            return .character(value)
        }
    }

    private static let byCharacter: [String: String] = [
        "a": "á",
        "c": "č",
        "d": "ď",
        "e": "éě",
        "i": "í",
        "n": "ň",
        "o": "ó",
        "r": "ř",
        "s": "š",
        "t": "ť",
        "u": "úů",
        "y": "ý",
        "z": "ž"
    ]
}
