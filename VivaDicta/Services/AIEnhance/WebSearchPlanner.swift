//
//  WebSearchPlanner.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation
import FoundationModels
import os

struct WebSearchPlan: Codable, Sendable {
    let shouldSearch: Bool
    let searchQuery: String?
    let reasoning: String?
}

@available(iOS 26, *)
@Generable(description: "A structured decision about whether to search the web and what focused query to use.")
struct WebSearchPlanSchema: Sendable {
    @Guide(description: "True when a web search would help answer the latest question. False when no focused web search should be run.")
    var shouldSearch: Bool

    @Guide(description: "A short focused web search query. Use 2 to 10 words when possible. Remove framing like 'search web', 'look up', 'online', 'latest', and 'current'. Use null when shouldSearch is false.")
    var searchQuery: String?

    @Guide(description: "A brief internal explanation of the planning decision.")
    var reasoning: String?

    var plan: WebSearchPlan {
        WebSearchPlan(
            shouldSearch: shouldSearch,
            searchQuery: searchQuery,
            reasoning: reasoning
        )
    }
}

@MainActor
enum WebSearchPlanner {
    private static let logger = Logger(category: .chatViewModel)

    static func makePlan(
        aiService: AIService,
        provider: AIProvider,
        model: String,
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) async -> WebSearchPlan? {
        let trimmedMessage = latestUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }

        do {
            let rawPlan: WebSearchPlan?
            if provider == .apple {
                guard #available(iOS 26, *) else {
                    return nil
                }
                rawPlan = try await makeApplePlan(
                    noteText: noteText,
                    recentMessages: recentMessages,
                    latestUserMessage: trimmedMessage
                )
            } else {
                rawPlan = try await makeCloudPlan(
                    aiService: aiService,
                    provider: provider,
                    model: model,
                    noteText: noteText,
                    recentMessages: recentMessages,
                    latestUserMessage: trimmedMessage
                )
            }

            guard let rawPlan else { return nil }
            let normalizedPlan = normalize(rawPlan)
            logger.logInfo(
                "Web planner provider=\(provider.rawValue) shouldSearch=\(normalizedPlan.shouldSearch) query='\(normalizedPlan.searchQuery ?? "")'"
            )
            return normalizedPlan
        } catch {
            logger.logWarning("Web planner failed: \(error.localizedDescription)")
            return nil
        }
    }

    @available(iOS 26, *)
    private static func makeApplePlan(
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) async throws -> WebSearchPlan? {
        guard AppleFoundationModelAvailability.isAvailable else {
            return nil
        }

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(
            model: model,
            instructions: planningSystemPrompt
        )

        let response = try await session.respond(
            generating: WebSearchPlanSchema.self,
            options: GenerationOptions(sampling: .greedy)
        ) {
            planningUserPrompt(
                noteText: noteText,
                recentMessages: recentMessages,
                latestUserMessage: latestUserMessage
            )
        }

        return response.content.plan
    }

    private static func makeCloudPlan(
        aiService: AIService,
        provider: AIProvider,
        model: String,
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) async throws -> WebSearchPlan? {
        let response = try await aiService.makeChatRequest(
            provider: provider,
            model: model,
            systemMessage: planningSystemPrompt,
            messages: [[
                "role": "user",
                "content": planningUserMessage(
                    noteText: noteText,
                    recentMessages: recentMessages,
                    latestUserMessage: latestUserMessage
                )
            ]]
        )

        return try decodePlan(from: response)
    }

    private static var planningSystemPrompt: String {
        """
        You prepare focused search queries for searching the public web.
        The user has explicitly enabled "Search web" for this turn.

        Decide whether a web search should run, then return structured JSON.

        Rules:
        - Infer the real web search topic from the latest user message, recent chat context, and the current note or notes.
        - Use web search only when online information, current facts, product documentation, release details, or other external knowledge would help.
        - When search is helpful, produce a short focused query that captures the topic to search online.
        - Remove framing such as "search web", "look up", "online", "latest", and "current".
        - Prefer concrete products, APIs, companies, technologies, people, or phrases from the note and recent chat.
        - Keep searchQuery concise - ideally 2 to 10 words, maximum 100 characters.
        - If no focused query can be inferred, set shouldSearch to false and searchQuery to null.
        - Do not answer the user's question. Only plan the search.
        - Return only a valid JSON object. Do not use markdown fences.

        Expected JSON shape:
        {
          "shouldSearch": true,
          "searchQuery": "short focused topic",
          "reasoning": "brief explanation"
        }
        """
    }

    @PromptBuilder
    @available(iOS 26, *)
    private static func planningUserPrompt(
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) -> Prompt {
        planningUserMessage(
            noteText: noteText,
            recentMessages: recentMessages,
            latestUserMessage: latestUserMessage
        )
    }

    private static func planningUserMessage(
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) -> String {
        let recentConversation = recentMessages.isEmpty
            ? "None"
            : recentMessages.map {
                "\($0.role.capitalized): \($0.content)"
            }
            .joined(separator: "\n")

        return """
        LATEST USER MESSAGE:
        \(latestUserMessage)

        RECENT CHAT:
        \(recentConversation)

        CURRENT NOTE OR NOTES:
        \(noteText)
        """
    }

    private static func decodePlan(from response: String) throws -> WebSearchPlan {
        let cleaned = extractJSONObject(from: response)
        guard let data = cleaned.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Planner response was not valid UTF-8.")
            )
        }
        return try JSONDecoder().decode(WebSearchPlan.self, from: data)
    }

    private static func extractJSONObject(from response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "{", trimmed.last == "}" {
            return trimmed
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        return trimmed
    }

    private static func normalize(_ plan: WebSearchPlan) -> WebSearchPlan {
        let normalizedQuery = plan.searchQuery.map { query in
            query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacing("\n", with: " ")
                .replacing("\t", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        }

        let finalQuery: String?
        if let normalizedQuery, !normalizedQuery.isEmpty {
            finalQuery = String(normalizedQuery.prefix(100))
        } else {
            finalQuery = nil
        }

        let shouldSearch = plan.shouldSearch && finalQuery != nil
        return WebSearchPlan(
            shouldSearch: shouldSearch,
            searchQuery: shouldSearch ? finalQuery : nil,
            reasoning: plan.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
