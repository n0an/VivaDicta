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
        /// Text to place on the pasteboard before opening Obsidian. Includes
        /// the line prefix + trailing newline so repeated appends stack as
        /// separate lines.
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
                              modeName: mode.name,
                              includeTime: false)
        guard !noteName.isEmpty else { return nil }

        let prefix = expand(template: mode.obsidianLinePrefix,
                            date: date,
                            presetName: presetName,
                            modeName: mode.name,
                            includeTime: true)

        let clipboardText = prefix + text + "\n"

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "new"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "file", value: noteName),
            URLQueryItem(name: "clipboard", value: nil),
            URLQueryItem(name: "append", value: "true")
        ]
        let vault = mode.obsidianVault.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vault.isEmpty {
            items.append(URLQueryItem(name: "vault", value: vault))
        }
        components.queryItems = items

        guard let url = components.url else { return nil }
        return Output(clipboardText: clipboardText, url: url)
    }

    private static func expand(template: String,
                               date: Date,
                               presetName: String?,
                               modeName: String,
                               includeTime: Bool) -> String {
        var result = template
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = String(format: "%04d", components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        let hour = String(format: "%02d", components.hour ?? 0)
        let minute = String(format: "%02d", components.minute ?? 0)

        result = result.replacing("{date}", with: "\(year)-\(month)-\(day)")
        result = result.replacing("{yyyy}", with: year)
        result = result.replacing("{MM}", with: month)
        result = result.replacing("{dd}", with: day)
        if includeTime {
            result = result.replacing("{time}", with: "\(hour):\(minute)")
            result = result.replacing("{HH}", with: hour)
            result = result.replacing("{mm}", with: minute)
        }
        result = result.replacing("{preset}", with: presetName ?? "")
        result = result.replacing("{mode}", with: modeName)
        return result
    }
}
