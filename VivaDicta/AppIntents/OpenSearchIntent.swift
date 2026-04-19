//
//  OpenSearchIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.19
//

import AppIntents

struct OpenSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Search"
    static let description = IntentDescription(
        "Opens VivaDicta and focuses the notes search field.",
        categoryName: "Navigation",
        searchKeywords: ["search", "find", "filter", "notes", "lookup"]
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
#if !os(macOS)
        await MainActor.run {
            PendingAppIntentAction.shared.enqueue(.search)
        }
#endif
        return .result()
    }
}
