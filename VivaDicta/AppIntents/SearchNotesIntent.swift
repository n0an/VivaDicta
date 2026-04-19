//
//  SearchNotesIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.19
//

import AppIntents

struct SearchNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Notes"
    static let description = IntentDescription(
        "Searches your notes for the query and returns matching entries. Chain with Copy to Clipboard, Open URL, or Repeat with Each to build multi-step shortcuts.",
        categoryName: "Notes",
        searchKeywords: ["find", "search", "filter", "query", "lookup", "notes"],
        resultValueName: "Matching Notes"
    )

    @Parameter(
        title: "Query",
        description: "Text to search for in the original or AI-enhanced transcription."
    )
    var query: String

    @Dependency var dataController: DataController

    /// Cap at 200 so a broad query (e.g. "the") doesn't hand thousands of entities to
    /// a downstream `Repeat with Each` - both slow and destructive for actions like
    /// "Append to Obsidian" that mutate external state per iteration.
    private static let maxMatches = 200

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[TranscriptionEntity]> & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw SearchNotesQueryEmptyError()
        }

        let matches = try dataController.transcriptionEntities(
            searching: trimmed,
            limit: Self.maxMatches
        )

        let dialog = AttributedString(
            localized: "Found ^[\(matches.count) note](inflect: true) matching \"\(trimmed)\"."
        )

        return .result(value: matches, dialog: "\(dialog)")
    }
}

struct SearchNotesQueryEmptyError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "Please provide a search query."
    }
}
