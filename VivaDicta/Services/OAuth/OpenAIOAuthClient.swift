// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Client for OpenAI's backend API using OAuth tokens.
enum OpenAIOAuthClient {
    private static let logger = Logger(category: .openAIOAuthAPI)

    /// Originator header required by the Codex endpoint.
    private static let originator = "codex_cli_rs"

    /// Default model for OpenAI OAuth requests.
    static let defaultModel = "gpt-5.4-mini"

    /// Models supported by the Codex endpoint (OpenAI OAuth).
    static let supportedModels: [String] = [
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.2",
        "gpt-5.1"
    ]

    /// Returns the model to use for the Codex endpoint.
    /// Falls back to default if the requested model isn't supported.
    static func resolveModel(_ requestedModel: String) -> String {
        if requestedModel.isEmpty {
            return defaultModel
        }
        if supportedModels.contains(requestedModel) {
            return requestedModel
        }
        return defaultModel
    }

    /// Sends an AI enhancement request via OpenAI's backend API.
    static func enhance(
        text: String,
        systemPrompt: String,
        model: String,
        accessToken: String,
        accountId: String?,
        onPartialResult: (@MainActor (String) -> Void)? = nil
    ) async throws -> String {
        guard let url = URL(string: OpenAIOAuthProvider.completionsEndpoint) else {
            throw OAuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(originator, forHTTPHeaderField: "originator")
        request.timeoutInterval = 60

        if let accountId {
            request.addValue(accountId, forHTTPHeaderField: "chatgpt-account-id")
        }

        let effectiveModel = resolveModel(model)
        logger.logInfo("OpenAI OAuth: using model '\(effectiveModel)' (requested: '\(model)')")

        let requestBody: [String: Any] = [
            "model": effectiveModel,
            "instructions": systemPrompt,
            "input": [
                ["role": "user", "content": text]
            ],
            "store": false,
            "stream": true
        ]

        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Collect error body from stream
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.logError("OpenAI API error: HTTP \(httpResponse.statusCode) — \(errorBody)")
            throw OAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse SSE stream, collect output_text.delta events
        var result = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            if jsonStr == "[DONE]" { break }

            guard let data = jsonStr.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            if type == "response.output_text.delta",
               let delta = event["delta"] as? String {
                result += delta
                if let onPartialResult {
                    await onPartialResult(result)
                }
            }
        }

        guard !result.isEmpty else {
            logger.logError("No output text received from OpenAI stream")
            throw OAuthError.invalidResponse
        }

        let finalResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if let onPartialResult {
            await onPartialResult(finalResult)
        }

        return finalResult
    }

    /// Fetches available models from OpenAI's backend.
    static func fetchModels(accessToken: String) async throws -> [String] {
        guard let url = URL(string: OpenAIOAuthProvider.modelsEndpoint) else {
            return [defaultModel]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(originator, forHTTPHeaderField: "originator")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return [defaultModel]
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return [defaultModel]
        }

        let modelIds = models.compactMap { $0["id"] as? String ?? $0["model"] as? String }
        return modelIds.isEmpty ? [defaultModel] : modelIds
    }
}
