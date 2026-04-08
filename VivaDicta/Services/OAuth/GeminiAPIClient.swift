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
        "gemini-3-flash-preview"
    ]

    /// Cloud Code Assist endpoint (non-streaming).
    private static let endpoint = "https://cloudcode-pa.googleapis.com/v1internal:generateContent"
    private static let streamingEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse"

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

    static func enhanceStreaming(
        text: String,
        systemPrompt: String,
        model: String,
        accessToken: String,
        projectId: String?,
        onPartialResult: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: streamingEndpoint) else {
            throw OAuthError.invalidResponse
        }

        let effectiveModel = resolveModel(model)
        logger.logInfo("Gemini OAuth streaming: model '\(effectiveModel)', projectId: \(projectId ?? "none")")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("google-cloud-sdk vscode_cloudshelleditor/0.1", forHTTPHeaderField: "User-Agent")
        request.addValue("gl-node/22.17.0", forHTTPHeaderField: "X-Goog-Api-Client")
        request.timeoutInterval = 60

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

        try Task.checkCancellation()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.logError("Gemini OAuth streaming error: HTTP \(httpResponse.statusCode) - \(errorBody)")

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

        var aggregatedText = ""
        var bufferedDataLines: [String] = []

        for try await line in bytes.lines {
            try Task.checkCancellation()

            if line.hasPrefix("data: ") {
                bufferedDataLines.append(String(line.dropFirst(6)))
                continue
            }

            guard line.isEmpty else {
                continue
            }

            aggregatedText = try await processStreamChunk(
                bufferedDataLines,
                currentAggregatedText: aggregatedText,
                onPartialResult: onPartialResult
            )
            bufferedDataLines.removeAll(keepingCapacity: true)
        }

        aggregatedText = try await processStreamChunk(
            bufferedDataLines,
            currentAggregatedText: aggregatedText,
            onPartialResult: onPartialResult
        )

        guard !aggregatedText.isEmpty else {
            throw OAuthError.invalidResponse
        }

        let finalResult = aggregatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        await onPartialResult(finalResult)
        return finalResult
    }

    private static func processStreamChunk(
        _ bufferedDataLines: [String],
        currentAggregatedText: String,
        onPartialResult: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard !bufferedDataLines.isEmpty else {
            return currentAggregatedText
        }

        let payload = bufferedDataLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload.isEmpty == false,
              let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return currentAggregatedText
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw EnhancementError.customError(message)
        }

        var aggregatedText = currentAggregatedText
        if let chunkText = streamingText(from: json) {
            if chunkText.hasPrefix(aggregatedText) {
                aggregatedText = chunkText
            } else {
                aggregatedText += chunkText
            }
            await onPartialResult(aggregatedText)
        }

        return aggregatedText
    }

    static func streamingText(from event: [String: Any]) -> String? {
        let geminiResponse: [String: Any]
        if let wrapped = event["response"] as? [String: Any] {
            geminiResponse = wrapped
        } else {
            geminiResponse = event
        }

        guard let candidates = geminiResponse["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            return nil
        }

        let text = parts.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }
}
