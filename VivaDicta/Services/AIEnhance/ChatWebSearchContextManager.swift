//
//  ChatWebSearchContextManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation

struct ChatWebSearchContextManager {
    static func assembleAugmentedPrompt(
        basePrompt: String,
        plannedQuery: String,
        payload: WebSearchPayload
    ) -> String {
        switch payload.status {
        case .success:
            let webBlocks = payload.results.enumerated().map { index, result in
                """
                WEB RESULT \(index + 1)
                Title: \(result.title ?? "Untitled")
                URL: \(result.url)
                Excerpt:
                \(result.text ?? "No content available.")
                """
            }
            .joined(separator: "\n\n")

            return """
            <WEB_SEARCH_RESULTS>
            Focused web search query used: \(plannedQuery)

            The following excerpts come from web search results.

            \(webBlocks)
            </WEB_SEARCH_RESULTS>

            \(basePrompt)
            """
        case .empty:
            let message = payload.message ?? "No relevant web results were found."
            return """
            <WEB_SEARCH_RESULTS>
            Focused web search query used: \(plannedQuery)

            \(message)
            </WEB_SEARCH_RESULTS>

            \(basePrompt)
            """
        case .error:
            return basePrompt
        }
    }

    static func assemblePlannerUnavailablePrompt(
        basePrompt: String,
        message: String
    ) -> String {
        """
        <WEB_SEARCH_RESULTS>
        \(message)
        </WEB_SEARCH_RESULTS>

        \(basePrompt)
        """
    }
}
