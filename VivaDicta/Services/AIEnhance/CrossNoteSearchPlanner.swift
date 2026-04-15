//
//  CrossNoteSearchPlanner.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation
import FoundationModels
import os

struct CrossNoteSearchPlan: Codable, Sendable {
    let shouldSearch: Bool
    let searchQuery: String?
    let reasoning: String?
}

struct CrossNoteSearchPlannerMessage: Sendable {
    let role: String
    let content: String
}

@available(iOS 26, *)
@Generable(description: "A structured decision about whether to search the user's other notes and what focused query to use.")
struct CrossNoteSearchPlanSchema: Sendable {
    @Guide(description: "True when searching the user's other notes would help answer the latest question. False when no focused search should be run.")
    var shouldSearch: Bool

    @Guide(description: "A short focused search query for the user's other notes. Use 2 to 8 words when possible. Remove framing like 'did I mention', 'other notes', 'similar', and 'search'. Use null when shouldSearch is false.")
    var searchQuery: String?

    @Guide(description: "A brief internal explanation of the planning decision.")
    var reasoning: String?

    var plan: CrossNoteSearchPlan {
        CrossNoteSearchPlan(
            shouldSearch: shouldSearch,
            searchQuery: searchQuery,
            reasoning: reasoning
        )
    }
}

@MainActor
enum CrossNoteSearchPlanner {
    private static let logger = Logger(category: .chatViewModel)

    static func makePlan(
        aiService: AIService,
        provider: AIProvider,
        model: String,
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) async -> CrossNoteSearchPlan? {
        let trimmedMessage = latestUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }

        do {
            let rawPlan: CrossNoteSearchPlan?
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
                "Cross-note planner provider=\(provider.rawValue) shouldSearch=\(normalizedPlan.shouldSearch) query='\(normalizedPlan.searchQuery ?? "")'"
            )
            return normalizedPlan
        } catch {
            logger.logWarning("Cross-note planner failed: \(error.localizedDescription)")
            return nil
        }
    }

    @available(iOS 26, *)
    private static func makeApplePlan(
        noteText: String,
        recentMessages: [CrossNoteSearchPlannerMessage],
        latestUserMessage: String
    ) async throws -> CrossNoteSearchPlan? {
        guard AppleFoundationModelAvailability.isAvailable else {
            return nil
        }

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(
            model: model,
            instructions: planningSystemPrompt
        )

        let response = try await session.respond(
            generating: CrossNoteSearchPlanSchema.self,
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
    ) async throws -> CrossNoteSearchPlan? {
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
        You prepare focused search queries for searching the user's other notes.
        The user has explicitly enabled "Search other notes" for this turn.

        Decide whether a cross-note search should run, then return structured JSON.

        Rules:
        - Infer the real search topic from the latest user message, recent chat context, and the current note.
        - When search is helpful, produce a short focused query that captures the topic to search in other notes.
        - Remove framing such as "did I mention", "other notes", "similar", "search", "find", and "elsewhere".
        - Prefer concrete entities, projects, concepts, people, or phrases from the note.
        - Keep searchQuery concise - ideally 2 to 8 words, maximum 80 characters.
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

        CURRENT NOTE:
        \(noteText)
        """
    }

    private static func decodePlan(from response: String) throws -> CrossNoteSearchPlan {
        let cleaned = extractJSONObject(from: response)
        guard let data = cleaned.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Planner response was not valid UTF-8.")
            )
        }
        return try JSONDecoder().decode(CrossNoteSearchPlan.self, from: data)
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

    private static func normalize(_ plan: CrossNoteSearchPlan) -> CrossNoteSearchPlan {
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
            finalQuery = String(normalizedQuery.prefix(80))
        } else {
            finalQuery = nil
        }

        let shouldSearch = plan.shouldSearch && finalQuery != nil
        return CrossNoteSearchPlan(
            shouldSearch: shouldSearch,
            searchQuery: shouldSearch ? finalQuery : nil,
            reasoning: plan.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
