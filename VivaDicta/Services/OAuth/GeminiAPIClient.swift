// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Client for Gemini API using OAuth tokens.
/// Uses the Cloud Code Assist endpoint (same as Gemini CLI / VS Code extension),
/// NOT the standard generativelanguage.googleapis.com endpoint.
enum GeminiAPIClient {
    private static let logger = Logger(category: .geminiOAuthAPI)

    /// Default model for Gemini OAuth requests.
    static let defaultModel = "gemini-2.5-flash"

    /// Models available via Gemini OAuth.
    static let supportedModels: [String] = [
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-3-pro-preview",
        "gemini-3-flash-preview",
        "gemini-3.1-pro-preview",
        "gemini-3.1-flash-lite-preview"
    ]

    /// Cloud Code Assist endpoint (non-streaming).
    private static let endpoint = "https://cloudcode-pa.googleapis.com/v1internal:generateContent"

    /// Returns the model to use. Falls back to default if empty.
    static func resolveModel(_ requestedModel: String) -> String {
        if requestedModel.isEmpty { return defaultModel }
        return requestedModel
    }

    /// Sends an AI enhancement request via Cloud Code Assist API using OAuth token.
    static func enhance(
        text: String,
        systemPrompt: String,
        model: String,
        accessToken: String,
        projectId: String?
    ) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw OAuthError.invalidResponse
        }

        let effectiveModel = resolveModel(model)
        logger.logInfo("Gemini OAuth: model '\(effectiveModel)', projectId: \(projectId ?? "none")")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("google-cloud-sdk vscode_cloudshelleditor/0.1", forHTTPHeaderField: "User-Agent")
        request.addValue("gl-node/22.17.0", forHTTPHeaderField: "X-Goog-Api-Client")
        request.timeoutInterval = 60

        // Cloud Code Assist request format — projectId in the body
        var requestBody: [String: Any] = [
            "model": effectiveModel,
            "userAgent": "vivadicta",
            "request": [
                "contents": [
                    [
                        "role": "user",
                        "parts": [["text": text]]
                    ]
                ],
                "systemInstruction": [
                    "parts": [["text": systemPrompt]]
                ],
                "generationConfig": [
                    "maxOutputTokens": 8192
                ]
            ]
        ]

        if let projectId {
            requestBody["project"] = projectId
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.logError("Gemini API error: HTTP \(httpResponse.statusCode) — \(errorBody)")
            if httpResponse.statusCode == 429 {
                if let errorData = errorBody.data(using: .utf8),
                   let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw EnhancementError.customError("Gemini rate limit reached. \(message)")
                }
                throw EnhancementError.rateLimitExceeded
            }
            throw OAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse Cloud Code Assist response — wraps standard Gemini response under .response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.logError("Gemini OAuth: failed to parse JSON response")
            throw OAuthError.invalidResponse
        }

        // Try Cloud Code Assist wrapper format first
        let geminiResponse: [String: Any]
        if let wrapped = json["response"] as? [String: Any] {
            geminiResponse = wrapped
        } else {
            geminiResponse = json
        }

        guard let candidates = geminiResponse["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let resultText = firstPart["text"] as? String else {
            let responseStr = String(data: data, encoding: .utf8) ?? "empty"
            logger.logError("Gemini OAuth: unexpected response format: \(responseStr)")
            throw OAuthError.invalidResponse
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
