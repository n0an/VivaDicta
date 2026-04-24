//
//  ObsidianURLBuilder.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.24
//

import Foundation

/// Builds the clipboard payload and `obsidian://new` URL used to append a
/// transcription to an Obsidian note. Shared between the main app and the
/// keyboard extension so both hand-off paths produce identical behaviour.
enum ObsidianURLBuilder {

    struct Output {
        /// Text to place on the pasteboard before opening Obsidian. Trailing
        /// newline ensures that if the user configures a repeating note name
        /// (e.g. `{date}`), repeated appends stack as separate lines.
        let clipboardText: String

        /// The fully-formed `obsidian://new?...` URL.
        let url: URL
    }

    /// Build the clipboard text + Obsidian URL for a transcription.
    ///
    /// - Parameters:
    ///   - text: The final transcription text (enhanced if AI ran, else raw).
    ///   - mode: The active `VivaMode` carrying the Obsidian configuration.
    ///   - presetName: Human-readable preset name for the `{preset}` placeholder.
    ///   - date: The moment the transcription completed. Parameterised for testability.
    /// - Returns: `nil` if the resulting note name is empty or the URL cannot
    ///   be constructed. Callers should treat `nil` as a no-op.
    static func build(text: String,
                      mode: VivaMode,
                      presetName: String?,
                      date: Date = Date()) -> Output? {
        let noteName = expand(template: mode.obsidianNoteTemplate,
                              date: date,
                              presetName: presetName,
                              modeName: mode.name)
        guard !noteName.isEmpty else { return nil }

        let clipboardText = text + "\n"

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "new"
        components.queryItems = [
            URLQueryItem(name: "file", value: noteName),
            URLQueryItem(name: "clipboard", value: nil),
            URLQueryItem(name: "append", value: "true")
        ]

        guard let url = components.url else { return nil }
        return Output(clipboardText: clipboardText, url: url)
    }

    private static func expand(template: String,
                               date: Date,
                               presetName: String?,
                               modeName: String) -> String {
        // Force Gregorian so `{date}` is always YYYY-MM-DD regardless of the
        // user's iOS calendar setting (Buddhist, Hebrew, etc. would otherwise
        // shift the year value).
        let gregorian = Calendar(identifier: .gregorian)
        let components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = (components.year ?? 0).formatted(.number.grouping(.never).precision(.integerLength(4...)))
        let twoDigits = IntegerFormatStyle<Int>.number.grouping(.never).precision(.integerLength(2...))
        let month = (components.month ?? 0).formatted(twoDigits)
        let day = (components.day ?? 0).formatted(twoDigits)
        let hour = (components.hour ?? 0).formatted(twoDigits)
        let minute = (components.minute ?? 0).formatted(twoDigits)
        let second = (components.second ?? 0).formatted(twoDigits)

        var result = template
        result = result.replacing("{date}", with: "\(year)-\(month)-\(day)")
        result = result.replacing("{yyyy}", with: year)
        result = result.replacing("{MM}", with: month)
        result = result.replacing("{dd}", with: day)
        result = result.replacing("{HH}", with: hour)
        result = result.replacing("{mm}", with: minute)
        result = result.replacing("{ss}", with: second)
        result = result.replacing("{preset}", with: presetName ?? "")
        result = result.replacing("{mode}", with: modeName)
        return result
    }
}
