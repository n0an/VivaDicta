//
//  GetLatestTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents

struct GetLatestTranscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Latest Note"
    static let description = IntentDescription(
        "Returns the most recently recorded note. Pipe its Text or Enhanced Text into other actions, like Copy to Clipboard or Open URL.",
        categoryName: "Notes",
        searchKeywords: ["latest", "recent", "last", "transcription", "note", "obsidian"],
        resultValueName: "Latest Note"
    )

    @Dependency var dataController: DataController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TranscriptionEntity> & ProvidesDialog {
        let recent = try dataController.transcriptionEntities(limit: 1)

        guard let latest = recent.first else {
            throw NoTranscriptionsAvailableError()
        }

        return .result(
            value: latest,
            dialog: "\(latest.text(withPrefix: 80))"
        )
    }
}

struct NoTranscriptionsAvailableError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "You haven't recorded any notes yet."
    }
}
