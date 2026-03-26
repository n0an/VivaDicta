// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Client for GitHub Copilot's OpenAI-compatible API.
/// Uses the Copilot token obtained via device code OAuth flow.
enum CopilotAPIClient {
    private static let logger = Logger(category: .copilotAPI)

    /// Base URL for Copilot's API.
    static let baseURL = "https://api.individual.githubcopilot.com"

    /// Default model for Copilot requests.
    static let defaultModel = "gpt-4o"

    /// Headers required by Copilot API.
    private static let staticHeaders: [String: String] = [
        "User-Agent": "GitHubCopilotChat/0.35.0",
        "Editor-Version": "vscode/1.107.0",
        "Editor-Plugin-Version": "copilot-chat/0.35.0",
        "Copilot-Integration-Id": "vscode-chat",
        "Openai-Intent": "conversation-edits"
    ]

    /// Sends an AI enhancement request via Copilot's API.
    static func enhance(
        text: String,
        systemPrompt: String,
        model: String,
        copilotToken: String
    ) async throws -> String {
        let effectiveModel = model.isEmpty ? defaultModel : model

        if isClaudeModel(effectiveModel) {
            return try await enhanceWithAnthropic(text: text, systemPrompt: systemPrompt, model: effectiveModel, token: copilotToken)
        } else {
            return try await enhanceWithOpenAI(text: text, systemPrompt: systemPrompt, model: effectiveModel, token: copilotToken)
        }
    }

    private static func isClaudeModel(_ model: String) -> Bool {
        model.hasPrefix("claude-")
    }

    // MARK: - Anthropic API (for Claude models)

    private static func enhanceWithAnthropic(
        text: String,
        systemPrompt: String,
        model: String,
        token: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw CopilotOAuthError.tokenExchangeFailed("Invalid URL")
        }

        logger.logInfo("Copilot: using Claude model '\(model)' via Anthropic API")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        for (key, value) in staticHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 8192
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        return try await executeRequest(request)
    }

    // MARK: - OpenAI API (for GPT, Gemini, Grok models)

    private static func enhanceWithOpenAI(
        text: String,
        systemPrompt: String,
        model: String,
        token: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw CopilotOAuthError.tokenExchangeFailed("Invalid URL")
        }

        logger.logInfo("Copilot: using model '\(model)' via OpenAI API")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        for (key, value) in staticHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        return try await executeRequest(request)
    }

    // MARK: - Shared Response Handling

    private static func executeRequest(_ request: URLRequest) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotOAuthError.tokenExchangeFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.logError("Copilot API error: HTTP \(httpResponse.statusCode) — \(errorBody)")
            if httpResponse.statusCode == 429 {
                throw EnhancementError.customError("Copilot rate limit reached. Please wait and try again.")
            }
            throw CopilotOAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            logger.logError("Copilot: failed to parse response")
            throw CopilotOAuthError.tokenExchangeFailed("Invalid response format")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fetch Available Models

    /// Fetches the list of models available for the user's Copilot plan.
    static func fetchModels(copilotToken: String) async -> [String] {
        guard let url = URL(string: "\(baseURL)/models") else { return [defaultModel] }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(copilotToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        for (key, value) in staticHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            return [defaultModel]
        }

        let chatModels = Array(Set(models.compactMap { $0["id"] as? String }
            .filter { !$0.contains("embedding") && !$0.contains("inference") }))
            .sorted()

        return chatModels.isEmpty ? [defaultModel] : chatModels
    }
}
