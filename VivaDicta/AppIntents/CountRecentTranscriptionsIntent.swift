//
//  CountRecentTranscriptionsIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents

struct CountRecentTranscriptionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Count Recent Notes"
    static let description = IntentDescription(
        "Counts notes recorded in the last month.",
        categoryName: "Notes",
        searchKeywords: ["count", "recent", "notes", "stats"],
        resultValueName: "Recent Notes Count"
    )

    @Dependency var dataController: DataController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let dateCutOff = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now

        let transcriptions = try dataController.transcriptionCount(matching: #Predicate {
            $0.timestamp > dateCutOff
        })

        let message = AttributedString(localized: "You've had ^[\(transcriptions) note](inflect: true).")

        return .result(
            value: transcriptions,
            dialog: "\(message)"
        )
    }
}
