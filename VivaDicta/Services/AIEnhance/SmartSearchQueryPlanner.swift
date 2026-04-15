//
//  SmartSearchQueryPlanner.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation
import FoundationModels
import os

struct SmartSearchQueryPlan: Codable, Sendable {
    let shouldSearch: Bool
    let searchQuery: String?
    let reasoning: String?
}

struct SmartSearchQueryPlannerMessage: Sendable {
    let role: String
    let content: String
}

@available(iOS 26, *)
@Generable(description: "A structured decision about whether a focused Smart Search retrieval query can be prepared for the user's notes.")
struct SmartSearchQueryPlanSchema: Sendable {
    @Guide(description: "True when a focused retrieval query can be prepared from the latest user message and recent chat context. False when no better focused query can be inferred.")
    var shouldSearch: Bool

    @Guide(description: "A short focused retrieval query for searching the user's notes. Use 2 to 8 words when possible. Remove framing like 'did I mention', 'in my notes', 'search', 'find', and 'something similar'. Use null when shouldSearch is false.")
    var searchQuery: String?

    @Guide(description: "A brief internal explanation of the planning decision.")
    var reasoning: String?

    var plan: SmartSearchQueryPlan {
        SmartSearchQueryPlan(
            shouldSearch: shouldSearch,
            searchQuery: searchQuery,
            reasoning: reasoning
        )
    }
}

@MainActor
enum SmartSearchQueryPlanner {
    private static let logger = Logger(category: .smartSearchChat)

    static func makePlan(
        aiService: AIService,
        provider: AIProvider,
        model: String,
        recentMessages: [SmartSearchQueryPlannerMessage],
        latestUserMessage: String
    ) async -> SmartSearchQueryPlan? {
        let trimmedMessage = latestUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }

        do {
            let rawPlan: SmartSearchQueryPlan?
            if provider == .apple {
                guard #available(iOS 26, *) else {
                    return nil
                }
                rawPlan = try await makeApplePlan(
                    recentMessages: recentMessages,
                    latestUserMessage: trimmedMessage
                )
            } else {
                rawPlan = try await makeCloudPlan(
                    aiService: aiService,
                    provider: provider,
                    model: model,
                    recentMessages: recentMessages,
                    latestUserMessage: trimmedMessage
                )
            }

            guard let rawPlan else { return nil }
            let normalizedPlan = normalize(rawPlan)
            logger.logInfo(
                "Smart Search planner provider=\(provider.rawValue) shouldSearch=\(normalizedPlan.shouldSearch) query='\(normalizedPlan.searchQuery ?? "")'"
            )
            return normalizedPlan
        } catch {
            logger.logWarning("Smart Search planner failed: \(error.localizedDescription)")
            return nil
        }
    }

    @available(iOS 26, *)
    private static func makeApplePlan(
        recentMessages: [SmartSearchQueryPlannerMessage],
        latestUserMessage: String
    ) async throws -> SmartSearchQueryPlan? {
        guard AppleFoundationModelAvailability.isAvailable else {
            return nil
        }

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(
            model: model,
            instructions: planningSystemPrompt
        )

        let response = try await session.respond(
            generating: SmartSearchQueryPlanSchema.self,
            options: GenerationOptions(sampling: .greedy)
        ) {
            planningUserPrompt(
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
        recentMessages: [SmartSearchQueryPlannerMessage],
        latestUserMessage: String
    ) async throws -> SmartSearchQueryPlan? {
        let response = try await aiService.makeChatRequest(
            provider: provider,
            model: model,
            systemMessage: planningSystemPrompt,
            messages: [[
                "role": "user",
                "content": planningUserMessage(
                    recentMessages: recentMessages,
                    latestUserMessage: latestUserMessage
                )
            ]]
        )

        return try decodePlan(from: response)
    }

    private static var planningSystemPrompt: String {
        """
        You prepare focused retrieval queries for searching the user's notes in Smart Search.
        Decide whether a cleaner, more focused retrieval query can be derived from the latest user message and recent chat context.

        Rules:
        - Infer the real search topic from the latest user message and recent chat context.
        - When a focused retrieval query is possible, set shouldSearch to true and provide a concise searchQuery.
        - Remove framing such as "did I mention", "in my notes", "search", "find", "something similar", and "do I have notes about".
        - Prefer concrete entities, products, projects, people, concepts, and phrases.
        - Keep searchQuery concise - ideally 2 to 8 words, maximum 80 characters.
        - If the latest message is too vague to improve, set shouldSearch to false and searchQuery to null.
        - Do not answer the user's question. Only prepare the retrieval query.
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
        recentMessages: [SmartSearchQueryPlannerMessage],
        latestUserMessage: String
    ) -> Prompt {
        planningUserMessage(
            recentMessages: recentMessages,
            latestUserMessage: latestUserMessage
        )
    }

    private static func planningUserMessage(
        recentMessages: [SmartSearchQueryPlannerMessage],
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
        """
    }

    private static func decodePlan(from response: String) throws -> SmartSearchQueryPlan {
        let cleaned = extractJSONObject(from: response)
        guard let data = cleaned.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Planner response was not valid UTF-8.")
            )
        }
        return try JSONDecoder().decode(SmartSearchQueryPlan.self, from: data)
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

    private static func normalize(_ plan: SmartSearchQueryPlan) -> SmartSearchQueryPlan {
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
        return SmartSearchQueryPlan(
            shouldSearch: shouldSearch,
            searchQuery: shouldSearch ? finalQuery : nil,
            reasoning: plan.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
