//
//  ChatCrossNoteContextManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

struct ChatCrossNoteContextManager {
    static func assembleAugmentedPrompt(
        query: String,
        payload: CrossNoteSearchPayload
    ) -> String {
        switch payload.status {
        case .success:
            let noteBlocks = payload.results.enumerated().map { index, result in
                """
                OTHER NOTE \(index + 1)
                Title: \(result.title)
                Date: \(result.date)
                Excerpt:
                \(result.excerpt)
                """
            }
            .joined(separator: "\n\n")

            return """
            <OTHER_NOTES_SEARCH_RESULTS>
            The following excerpts come from other notes outside the current note.

            \(noteBlocks)
            </OTHER_NOTES_SEARCH_RESULTS>

            USER QUESTION:
            \(query)
            """
        case .empty:
            let message = payload.message ?? "No relevant other notes were found outside the current note."
            return """
            <OTHER_NOTES_SEARCH_RESULTS>
            \(message)
            </OTHER_NOTES_SEARCH_RESULTS>

            USER QUESTION:
            \(query)
            """
        case .error:
            return query
        }
    }
}
