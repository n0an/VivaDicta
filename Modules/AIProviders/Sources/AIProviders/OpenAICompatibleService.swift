// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import AICore

/// Pure HTTP wrapper for OpenAI-compatible chat-completions endpoints
/// (`POST /v1/chat/completions` with Bearer auth and standard `messages`
/// body). Stateless apart from its dependencies.
///
/// Lives in the `AIProviders` module. Used by ~10 cloud providers (OpenAI, Groq, Cerebras,
/// Mistral, xAI/Grok, OpenRouter, Z.AI, Kimi, Vercel AI Gateway,
/// HuggingFace) that all share the OpenAI shape. Indirectly used by
/// Ollama and Custom OpenAI through the static `buildRequestBody` and
/// `streamingDelta` helpers - those callers do their own status-code
/// mapping for provider-specific friendly errors and so call the static
/// helpers directly rather than going through `enhance` / `enhanceStreaming`.
///
/// ## Why static helpers + instance methods
///
/// The shared utilities (`buildRequestBody`, `streamingDelta`) are static
/// because callers like Ollama and Custom OpenAI build their own
/// `URLRequest` with custom timeouts and error mapping, then just need
/// the body shape and the SSE delta parser. Cloud providers that match
/// the standard 429/5xx/default error mapping can call the instance
/// `enhance` / `enhanceStreaming` methods directly.
public struct OpenAICompatibleService: Sendable {
    private let networkService: any NetworkService
    private let logger: Logger

    public init(networkService: any NetworkService, logger: Logger) {
        self.networkService = networkService
        self.logger = logger
    }

    // MARK: - Static utilities (also called by non-cloud paths)

    /// Builds an OpenAI-compatible chat-completions body. Applies model
    /// quirks: GPT-5 series omits `temperature` (uses `reasoning_effort`
    /// instead); reasoning models pick up extra body parameters from
    /// `ReasoningConfig`.
    public static func buildRequestBody(
        modelName: String,
        systemMessage: String,
        userMessage: String,
        stream: Bool
    ) -> [String: Any] {
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemMessage],
            ["role": "user", "content": userMessage]
        ]

        var requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "stream": stream
        ]

        if modelName.lowercased().hasPrefix("gpt-5") == false {
            requestBody["temperature"] = 0.3
        }

        if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: modelName) {
            requestBody["reasoning_effort"] = reasoningEffort
        }

        if let extraBody = ReasoningConfig.getExtraBodyParameters(for: modelName) {
            for (key, value) in extraBody {
                requestBody[key] = value
            }
        }

        return requestBody
    }

    /// Parses one SSE `data:` line from an OpenAI-compatible streaming
    /// response and returns the text delta if present. Returns `nil` for
    /// non-data lines, the `[DONE]` sentinel, or malformed payloads.
    /// Handles both string-content deltas and the newer array-of-text
    /// deltas (responses-API shape).
    public static func streamingDelta(from line: String) -> String? {
        guard line.hasPrefix("data:") else {
            return nil
        }

        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard payload.isEmpty == false, payload != "[DONE]",
              let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            return nil
        }

        if let delta = firstChoice["delta"] as? [String: Any] {
            if let content = delta["content"] as? String, content.isEmpty == false {
                return content
            }

            if let contentItems = delta["content"] as? [[String: Any]] {
                let text = contentItems.compactMap { $0["text"] as? String }.joined()
                return text.isEmpty ? nil : text
            }
        }

        if let text = firstChoice["text"] as? String, text.isEmpty == false {
            return text
        }

        return nil
    }

    // MARK: - Non-streaming enhance

    /// Non-streaming chat-completions request. Standard 429/5xx error
    /// mapping; non-200 non-429 non-5xx maps to
    /// `.customError("HTTP <status>: <body>")`.
    ///
    /// Returns the filtered/trimmed `choices[0].message.content`. Throws
    /// `.enhancementFailed` on a malformed 200 body.
    public func enhance(
        url: URL,
        modelName: String,
        systemMessage: String,
        userMessage: String,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let requestBody = Self.buildRequestBody(
            modelName: modelName,
            systemMessage: systemMessage,
            userMessage: userMessage,
            stream: false
        )
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

            if httpResponse.statusCode == 200 {
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = jsonResponse["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let enhancedText = message["content"] as? String else {
                    logger.logError("OpenAI-compatible enhance - malformed 200 body")
                    throw EnhancementError.enhancementFailed
                }

                let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                return filteredText
            } else if httpResponse.statusCode == 429 {
                logger.logWarning("OpenAI-compatible enhance - rate limit exceeded (429)")
                throw EnhancementError.rateLimitExceeded
            } else if (500...599).contains(httpResponse.statusCode) {
                logger.logError("OpenAI-compatible enhance - server error \(httpResponse.statusCode)")
                throw EnhancementError.serverError
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                logger.logError("OpenAI-compatible enhance - HTTP \(httpResponse.statusCode): \(errorString.prefix(500))")
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as EnhancementError {
            throw error
        } catch let error as URLError {
            logger.logError("OpenAI-compatible enhance - URLError \(error.code.rawValue): \(error.localizedDescription)")
            throw error
        } catch {
            logger.logError("OpenAI-compatible enhance - error: \(error.localizedDescription)")
            throw EnhancementError.customError(error.localizedDescription)
        }
    }

    // MARK: - Streaming enhance

    /// Streaming chat-completions request via SSE. `errorPrefix` is
    /// prepended to the default error message; `notFoundMessage` /
    /// `unauthorizedMessage` override the 404 / 401 default messages
    /// when provided (used by Ollama and Custom OpenAI to surface
    /// model-name and auth hints).
    ///
    /// Calls `onPartialResponse` on the main actor as each SSE delta
    /// arrives. Returns the filtered/trimmed final text. Throws
    /// `.enhancementFailed` if no deltas arrived.
    public func enhanceStreaming(
        url: URL,
        modelName: String,
        systemMessage: String,
        userMessage: String,
        headers: [String: String],
        timeout: TimeInterval,
        errorPrefix: String,
        notFoundMessage: String? = nil,
        unauthorizedMessage: String? = nil,
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let requestBody = Self.buildRequestBody(
            modelName: modelName,
            systemMessage: systemMessage,
            userMessage: userMessage,
            stream: true
        )
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let (bytes, httpResponse) = try await networkService.bytes(for: request, acceptableStatusCodes: Set<Int>.acceptAny)

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            switch httpResponse.statusCode {
            case 401 where unauthorizedMessage != nil:
                logger.logError("OpenAI-compatible streaming - 401: \(errorString.prefix(500))")
                throw EnhancementError.customError(unauthorizedMessage ?? errorString)
            case 404 where notFoundMessage != nil:
                logger.logError("OpenAI-compatible streaming - 404: \(errorString.prefix(500))")
                throw EnhancementError.customError(notFoundMessage ?? errorString)
            case 429:
                logger.logWarning("OpenAI-compatible streaming - rate limit exceeded (429)")
                throw EnhancementError.rateLimitExceeded
            case 500...599:
                logger.logError("OpenAI-compatible streaming - server error \(httpResponse.statusCode)")
                throw EnhancementError.serverError
            default:
                logger.logError("OpenAI-compatible streaming - HTTP \(httpResponse.statusCode): \(errorString.prefix(500))")
                throw EnhancementError.customError("\(errorPrefix) (HTTP \(httpResponse.statusCode)): \(errorString)")
            }
        }

        var aggregatedText = ""
        for try await line in bytes.lines {
            if let delta = Self.streamingDelta(from: line) {
                aggregatedText += delta
                await onPartialResponse(aggregatedText)
            }
        }

        guard !aggregatedText.isEmpty else {
            logger.logError("OpenAI-compatible streaming - finished with empty aggregated text")
            throw EnhancementError.enhancementFailed
        }

        let trimmed = aggregatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = AIEnhancementOutputFilter.filter(trimmed)
        if filtered != aggregatedText {
            await onPartialResponse(filtered)
        }
        return filtered
    }

    // MARK: - API key verification

    /// Probes a GET endpoint with `Authorization: Bearer <key>` and
    /// returns `true` if the response is 200. Used by providers whose
    /// verify path is "hit a cheap GET endpoint and see if auth works"
    /// instead of generating a tiny chat completion - currently
    /// Cerebras (`/v1/models`), Mistral (`/v1/models`), and Vercel AI
    /// Gateway (`/v1/credits`).
    ///
    /// Never throws. `providerName` is used only for log lines.
    public func verifyGETEndpoint(
        _ key: String,
        url: URL,
        providerName: String
    ) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        logger.logNotice("🔑 Verifying API key for \(providerName) provider at \(url.absoluteString)")

        do {
            let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)
            let isValid = httpResponse.statusCode == 200

            if !isValid {
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.logNotice("🔑 API key verification failed for \(providerName) - Status: \(httpResponse.statusCode) - \(exactAPIError)")
                } else {
                    logger.logNotice("🔑 API key verification failed for \(providerName) - Status: \(httpResponse.statusCode)")
                }
            }

            return isValid
        } catch {
            logger.logNotice("🔑 API key verification failed for \(providerName): \(error.localizedDescription)")
            return false
        }
    }

    /// Probes an OpenAI-compatible chat-completions endpoint with a
    /// minimal `messages: [{ "role": "user", "content": "test" }]`
    /// request and returns `true` if the response is 200. Used by
    /// every provider that goes through the generic
    /// `verifyOpenAICompatibleAPIKey` path in `AIService` - currently
    /// OpenAI, Groq, OpenRouter, Z.AI, Kimi, Grok, HuggingFace, plus
    /// any future provider that falls through the `default:` branch
    /// (Gemini and Copilot also land here today via fall-through).
    ///
    /// Callers should pass `maxTokens: 1` (or another small cap) to
    /// avoid letting the verification probe generate a full default
    /// response on heavy models (e.g. HuggingFace's
    /// `openai/gpt-oss-120b`, Grok's frontier model) - uncapped probes
    /// can be slow enough to risk false-negative timeouts.
    ///
    /// Never throws. `providerName` is used only for log lines.
    public func verifyChatCompletionsAPIKey(
        _ key: String,
        baseURL: String,
        defaultModel: String,
        providerName: String,
        maxTokens: Int? = nil
    ) async -> Bool {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        var testBody: [String: Any] = [
            "model": defaultModel,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        if let maxTokens {
            testBody["max_tokens"] = maxTokens
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)

        logger.logNotice("🔑 Verifying API key for \(providerName) provider at \(url.absoluteString)")

        do {
            let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)
            let isValid = httpResponse.statusCode == 200

            if !isValid {
                if let exactAPIError = String(data: data, encoding: .utf8) {
                    logger.logNotice("🔑 API key verification failed for \(providerName) - Status: \(httpResponse.statusCode) - \(exactAPIError)")
                } else {
                    logger.logNotice("🔑 API key verification failed for \(providerName) - Status: \(httpResponse.statusCode)")
                }
            }

            return isValid
        } catch {
            logger.logNotice("🔑 API key verification failed for \(providerName): \(error.localizedDescription)")
            return false
        }
    }
}
