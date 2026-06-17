// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import AICore

/// Pure HTTP wrapper for Anthropic's Messages API. Stateless apart from
/// its dependencies.
///
/// Lives in the app target alongside `OllamaService` and `CustomOpenAIService`
/// as the third step of the AIService decomposition (Phase 2a of the
/// architecture migration). `AIService` retains ownership of routing
/// decisions (CLI Server fallback, model selection, API-key lookup) and
/// the observable connection state; this struct just runs the HTTP calls.
///
/// ## Endpoint shape
///
/// Anthropic does NOT use the OpenAI-compatible `/v1/chat/completions`
/// shape. Differences:
/// - `POST /v1/messages` instead of `/v1/chat/completions`
/// - System prompt is a top-level `system` field, not a message in the
///   conversation array
/// - `max_tokens` is required
/// - Authorization uses `x-api-key` + `anthropic-version: 2023-06-01`
///   headers, not `Authorization: Bearer ...`
/// - Streaming uses `content_block_delta` SSE events with a `delta.text`
///   payload, not OpenAI's `data: {choices: [{delta: {content: ...}}]}`
///   shape
struct AnthropicService: Sendable {
    private let networkService: any NetworkService
    private let logger: Logger
    private let baseTimeout: TimeInterval

    init(networkService: any NetworkService, logger: Logger, baseTimeout: TimeInterval) {
        self.networkService = networkService
        self.logger = logger
        self.baseTimeout = baseTimeout
    }

    /// Non-streaming enhance via `POST /v1/messages`. Returns the
    /// filtered/trimmed response text.
    ///
    /// Throws `EnhancementError.rateLimitExceeded` on 429,
    /// `.serverError` on 5xx, `.customError(_)` on other non-200,
    /// `.enhancementFailed` on malformed body.
    func enhance(
        systemMessage: String,
        userMessage: String,
        apiKey: String,
        model: String
    ) async throws -> String {
        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = baseTimeout

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

            if httpResponse.statusCode == 200 {
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = jsonResponse["content"] as? [[String: Any]],
                      let firstContent = content.first,
                      let enhancedText = firstContent["text"] as? String else {
                    logger.logError("Anthropic enhance - malformed 200 body")
                    throw EnhancementError.enhancementFailed
                }

                let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                return filteredText
            } else if httpResponse.statusCode == 429 {
                logger.logWarning("Anthropic enhance - rate limit exceeded (429)")
                throw EnhancementError.rateLimitExceeded
            } else if (500...599).contains(httpResponse.statusCode) {
                logger.logError("Anthropic enhance - server error \(httpResponse.statusCode)")
                throw EnhancementError.serverError
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                logger.logError("Anthropic enhance - HTTP \(httpResponse.statusCode): \(errorString.prefix(500))")
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as EnhancementError {
            throw error
        } catch let error as URLError {
            logger.logError("Anthropic enhance - URLError \(error.code.rawValue): \(error.localizedDescription)")
            throw error
        } catch {
            logger.logError("Anthropic enhance - error: \(error.localizedDescription)")
            throw EnhancementError.customError(error.localizedDescription)
        }
    }

    /// Streaming enhance via `POST /v1/messages` with `stream: true`.
    /// Parses Anthropic's SSE event format (`content_block_delta` events
    /// carry `delta.text` chunks; `error` events with type
    /// `overloaded_error` map to `EnhancementError.serverError`).
    ///
    /// Calls `onPartialResponse` on the main actor as each delta arrives,
    /// then once more if the post-filter text differs from the raw
    /// aggregate. Returns the filtered/trimmed final text.
    func enhanceStreaming(
        systemMessage: String,
        userMessage: String,
        apiKey: String,
        model: String,
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = baseTimeout

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": [
                ["role": "user", "content": userMessage]
            ],
            "stream": true
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let (bytes, httpResponse) = try await networkService.bytes(for: request, acceptableStatusCodes: Set<Int>.acceptAny)

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "Could not decode error response."

            if httpResponse.statusCode == 429 {
                logger.logWarning("Anthropic streaming - rate limit exceeded (429)")
                throw EnhancementError.rateLimitExceeded
            } else if (500...599).contains(httpResponse.statusCode) {
                logger.logError("Anthropic streaming - server error \(httpResponse.statusCode)")
                throw EnhancementError.serverError
            } else {
                logger.logError("Anthropic streaming - HTTP \(httpResponse.statusCode): \(errorString.prefix(500))")
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }
        }

        var aggregatedText = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard payload.isEmpty == false,
                  let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else {
                continue
            }

            if type == "content_block_delta",
               let delta = event["delta"] as? [String: Any],
               let deltaType = delta["type"] as? String,
               deltaType == "text_delta",
               let text = delta["text"] as? String,
               text.isEmpty == false {
                aggregatedText += text
                await onPartialResponse(aggregatedText)
                continue
            }

            if type == "error",
               let error = event["error"] as? [String: Any] {
                let message = (error["message"] as? String) ?? "Anthropic streaming error"
                let errorType = error["type"] as? String
                if errorType == "overloaded_error" {
                    logger.logError("Anthropic streaming - overloaded_error event: \(message)")
                    throw EnhancementError.serverError
                }
                logger.logError("Anthropic streaming - error event (type: \(errorType ?? "unknown")): \(message)")
                throw EnhancementError.customError(message)
            }
        }

        guard !aggregatedText.isEmpty else {
            logger.logError("Anthropic streaming - finished with empty aggregated text")
            throw EnhancementError.enhancementFailed
        }

        let trimmed = aggregatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = AIEnhancementOutputFilter.filter(trimmed)
        if filtered != aggregatedText {
            await onPartialResponse(filtered)
        }
        return filtered
    }

    /// Probes the Anthropic API with a minimal Messages request and
    /// returns whether the key is accepted. Never throws.
    func verifyAPIKey(_ key: String) async -> Bool {
        let url = URL(string: AIProvider.anthropic.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let testBody: [String: Any] = [
            "model": AIProvider.anthropic.defaultModel,
            "max_tokens": 1024,
            "system": "You are a test system.",
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)

        do {
            let (_, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}
