//
//  ObsidianURLBuilder.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.24
//

import Foundation
import AppGroup

/// Builds the clipboard payload and URL used to hand a transcription to
/// Obsidian. The main app either opens the URL itself or publishes it to the
/// App Group for the keyboard extension, so both paths get the same URL.
///
/// Two styles:
/// - Standard: `obsidian://new?file=<note name>&clipboard&append=true`, with
///   the note name expanded from the user's template.
/// - Custom URL: the user writes the whole URL (any scheme, e.g. Advanced URI
///   or `obsidian://open?...&prepend={text}`), and every placeholder value is
///   percent-encoded into it.
enum ObsidianURLBuilder {

    struct Output {
        /// Text to place on the pasteboard before opening Obsidian. Trailing
        /// newline ensures that if the user configures a repeating note name
        /// (e.g. `{date}`), repeated appends stack as separate lines.
        let clipboardText: String

        /// The fully-formed URL to open.
        let url: URL
    }

    /// Build the clipboard text + Obsidian URL for a transcription.
    ///
    /// - Parameters:
    ///   - text: The final transcription text (enhanced if AI ran, else raw).
    ///   - originalText: Raw transcription for the `{original}` placeholder.
    ///     Defaults to `text` when the caller has no separate raw text.
    ///   - template: Note-name template carrying placeholders like `{date}`.
    ///     Stored globally in Settings → Integrations.
    ///   - customURLTemplate: Full URL template. When non-empty it replaces the
    ///     standard `obsidian://new` URL entirely.
    ///   - modeName: Human-readable mode name for the `{mode}` placeholder.
    ///   - presetName: Human-readable preset name for the `{preset}` placeholder.
    ///   - transcriptionID: UUID for the `{id}` placeholder.
    ///   - date: The moment the transcription completed. Parameterised for testability.
    /// - Returns: `nil` if the resulting note name is empty or the URL cannot
    ///   be constructed. Callers should treat `nil` as a no-op.
    static func build(text: String,
                      originalText: String? = nil,
                      template: String,
                      customURLTemplate: String? = nil,
                      modeName: String,
                      presetName: String?,
                      transcriptionID: UUID? = nil,
                      date: Date = Date()) -> Output? {
        let values = NoteTemplate.Values(
            date: date,
            text: text,
            original: originalText ?? text,
            mode: modeName,
            preset: presetName ?? "",
            id: transcriptionID?.uuidString ?? ""
        )
        let clipboardText = text + "\n"

        let trimmedCustom = customURLTemplate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCustom.isEmpty {
            let expanded = NoteTemplate.expand(trimmedCustom, values: values, escaping: .url)
            // `URL(string:)` percent-encodes invalid characters the user typed
            // in the literal part (spaces, Cyrillic) on iOS 17+.
            guard let url = URL(string: expanded), url.scheme != nil else { return nil }
            return Output(clipboardText: clipboardText, url: url)
        }

        let noteName = NoteTemplate.expand(template, values: values)
        guard !noteName.isEmpty else { return nil }

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

    /// Same as `build`, reading the note-name template and custom URL from
    /// Settings → Integrations.
    static func buildFromSettings(text: String,
                                  originalText: String?,
                                  modeName: String,
                                  presetName: String?,
                                  transcriptionID: UUID?,
                                  date: Date = Date()) -> Output? {
        let defaults = UserDefaultsStorage.appPrivate
        // Trim and fall back to the default if the user cleared the field -
        // an empty note name would silently fail to build a URL.
        let trimmedTemplate = (defaults.string(forKey: UserDefaultsStorage.Keys.obsidianNoteTemplate) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let template = trimmedTemplate.isEmpty ? UserDefaultsStorage.defaultObsidianNoteTemplate : trimmedTemplate
        let customURLTemplate = defaults.bool(forKey: UserDefaultsStorage.Keys.isObsidianCustomURLEnabled)
            ? defaults.string(forKey: UserDefaultsStorage.Keys.obsidianCustomURLTemplate)
            : nil

        return build(text: text,
                     originalText: originalText,
                     template: template,
                     customURLTemplate: customURLTemplate,
                     modeName: modeName,
                     presetName: presetName,
                     transcriptionID: transcriptionID,
                     date: date)
    }
}
