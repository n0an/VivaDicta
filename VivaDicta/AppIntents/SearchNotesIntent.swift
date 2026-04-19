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

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[TranscriptionEntity]> & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .result(value: [], dialog: "Please provide a search query.")
        }

        let matches = try dataController.transcriptionEntities(matching: #Predicate { transcription in
            transcription.text.localizedStandardContains(trimmed) ||
            (transcription.enhancedText?.localizedStandardContains(trimmed) ?? false)
        })

        let dialog = AttributedString(
            localized: "Found ^[\(matches.count) note](inflect: true) matching \"\(trimmed)\"."
        )

        return .result(value: matches, dialog: "\(dialog)")
    }
}
