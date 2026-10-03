//
//  NoteTemplate.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.09.30
//

import Foundation

/// Expands `{placeholder}` tokens in user-editable templates: the Obsidian note
/// name, the custom Obsidian URL and the folder-export file name / entry.
///
/// Expansion is a single left-to-right pass, so a placeholder value that itself
/// contains `{date}` (e.g. dictated text) is inserted literally and never
/// re-expanded. Unknown tokens are kept as typed.
nonisolated enum NoteTemplate {

    /// Values available to a template. Content fields default to empty so
    /// callers only fill in what their context actually has.
    nonisolated struct Values: Sendable {
        var date: Date
        /// Final text: the latest AI variation if one exists, else the original.
        var text: String = ""
        /// Raw transcription before any AI processing.
        var original: String = ""
        var mode: String = ""
        var preset: String = ""
        /// Transcription UUID string.
        var id: String = ""
        /// Full generated markdown document (folder export only).
        var markdown: String = ""
    }

    /// How placeholder values are escaped before insertion. The literal parts
    /// of the template are never touched - the user owns those.
    nonisolated enum Escaping: Sendable {
        case none
        /// Percent-encodes every value down to RFC 3986 unreserved characters,
        /// so a value can never break out of the query parameter it sits in.
        case url
        /// Makes a value safe to use inside a single path component: slashes,
        /// colons and line breaks become separators, control characters go.
        case filename
    }

    /// Placeholder names, in the order they are listed in Settings.
    static let placeholderNames = [
        "date", "time", "yyyy", "MM", "dd", "HH", "mm", "ss",
        "text", "original", "mode", "preset", "id"
    ]

    /// Human-readable placeholder list for Settings footers.
    static var placeholderList: String {
        placeholderNames.map { "{\($0)}" }.joined(separator: ", ")
    }

    static func expand(_ template: String, values: Values, escaping: Escaping = .none) -> String {
        let resolved = resolvedValues(values)
        var result = ""
        var index = template.startIndex

        while index < template.endIndex {
            let character = template[index]
            guard character == "{",
                  let close = template[index...].firstIndex(of: "}") else {
                result.append(character)
                index = template.index(after: index)
                continue
            }

            let name = String(template[template.index(after: index)..<close])
            if let value = resolved[name] {
                result += escape(value, escaping)
                index = template.index(after: close)
            } else {
                // Not a known token: emit the brace alone and rescan from the
                // next character so `{{text}` still expands the inner token.
                result.append(character)
                index = template.index(after: index)
            }
        }
        return result
    }

    private static func resolvedValues(_ values: Values) -> [String: String] {
        // Force Gregorian so `{date}` is always YYYY-MM-DD regardless of the
        // user's iOS calendar setting (Buddhist, Hebrew, etc. would otherwise
        // shift the year value).
        let gregorian = Calendar(identifier: .gregorian)
        let components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: values.date)
        let year = (components.year ?? 0).formatted(.number.grouping(.never).precision(.integerLength(4...)))
        let twoDigits = IntegerFormatStyle<Int>.number.grouping(.never).precision(.integerLength(2...))
        let month = (components.month ?? 0).formatted(twoDigits)
        let day = (components.day ?? 0).formatted(twoDigits)
        let hour = (components.hour ?? 0).formatted(twoDigits)
        let minute = (components.minute ?? 0).formatted(twoDigits)
        let second = (components.second ?? 0).formatted(twoDigits)

        return [
            "date": "\(year)-\(month)-\(day)",
            "time": "\(hour):\(minute)",
            "yyyy": year,
            "MM": month,
            "dd": day,
            "HH": hour,
            "mm": minute,
            "ss": second,
            "text": values.text,
            "original": values.original,
            "mode": values.mode,
            "preset": values.preset,
            "id": values.id,
            "markdown": values.markdown
        ]
    }

    private static let urlValueAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func escape(_ value: String, _ escaping: Escaping) -> String {
        switch escaping {
        case .none:
            return value
        case .url:
            return value.addingPercentEncoding(withAllowedCharacters: urlValueAllowed) ?? ""
        case .filename:
            var result = ""
            for scalar in value.unicodeScalars {
                switch scalar {
                case "/", "\\", ":":
                    result.append("-")
                case "\n", "\r", "\t":
                    result.append(" ")
                default:
                    if CharacterSet.controlCharacters.contains(scalar) { continue }
                    result.unicodeScalars.append(scalar)
                }
            }
            return result
        }
    }
}
