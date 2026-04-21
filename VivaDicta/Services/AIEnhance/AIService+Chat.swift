//
//  AIService+Chat.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import Foundation
import FoundationModels
import os

/// Multi-turn chat support for AIService.
///
/// These methods accept explicit provider/model parameters (independent of `selectedMode`)
/// and support conversation history as an array of messages.
extension AIService {

    // MARK: - Provider Readiness

    /// Checks if a specific provider is ready for chat (has credentials or is otherwise available).
    func isChatProviderReady(_ provider: AIProvider) -> Bool {
        switch provider {
        case .apple:
            return connectedProviders.contains(.apple)
        case .ollama:
            return true // Connection checked at request time
        case .customOpenAI:
            return !customOpenAIEndpointURL.isEmpty && !customOpenAIModelName.isEmpty
        case .openAI:
            return isOpenAISignedIn || provider.apiKey != nil
        case .gemini:
            return isGeminiSignedIn || provider.apiKey != nil
        case .copilot:
            return isCopilotSignedIn
        default:
            return provider.apiKey != nil
        }
    }

    // MARK: - Streaming Chat Request

    /// Multi-turn streaming request with explicit provider and model.
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use.
    ///   - model: The model name to use.
    ///   - systemMessage: The system prompt.
    ///   - messages: Conversation history as `[["role": "user"/"assistant", "content": "..."]]`.
    ///   - onPartialResponse: Callback for streaming text chunks (accumulated).
    /// - Returns: The complete response text.
    func makeChatStreamingRequest(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let route = chatStreamingRoute(for: provider, model: model)

        switch route {
        case .anthropic:
            guard let apiKey = provider.apiKey else {
                throw EnhancementError.notConfigured
            }
            return try await makeAnthropicChatStreamingRequest(
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                apiKey: apiKey,
                onPartialResponse: onPartialResponse
            )

        case .openAICompatibleCloud:
            guard let apiKey = provider.apiKey else {
                throw EnhancementError.notConfigured
            }
            return try await makeOpenAIChatStreamingRequest(
                url: URL(string: provider.baseURL)!,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: ["Authorization": "Bearer \(apiKey)"],
                onPartialResponse: onPartialResponse
            )

        case .copilot:
            let token = try await CopilotOAuthManager.shared.validCopilotToken()
            guard let url = URL(string: "\(CopilotAPIClient.baseURL)/chat/completions") else {
                throw EnhancementError.customError("Invalid Copilot URL")
            }
            return try await makeOpenAIChatStreamingRequest(
                url: url,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: CopilotAPIClient.chatHeaders(copilotToken: token),
                onPartialResponse: onPartialResponse
            )

        case .ollama:
            let serverURL = ollamaServerURL
            guard let url = URL(string: "\(serverURL)/v1/chat/completions") else {
                throw EnhancementError.customError("Invalid Ollama server URL: \(serverURL)")
            }
            return try await makeOpenAIChatStreamingRequest(
                url: url,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: [:],
                onPartialResponse: onPartialResponse
            )

        case .customOpenAI:
            let endpointURL = customOpenAIRequestURL
            guard !endpointURL.isEmpty, let url = URL(string: endpointURL) else {
                throw EnhancementError.customError("Custom AI endpoint URL is not configured")
            }
            var headers: [String: String] = [:]
            if let apiKey = AIProvider.customOpenAI.apiKey, !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }
            return try await makeOpenAIChatStreamingRequest(
                url: url,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: headers,
                onPartialResponse: onPartialResponse
            )

        case .openAIOAuth:
            do {
                let oauthProvider = OpenAIOAuthProvider()
                let (token, accountId, _) = try await OAuthManager.shared.validAccessToken(for: oauthProvider)
                return try await OpenAIOAuthClient.chatStreaming(
                    systemMessage: systemMessage,
                    messages: messages,
                    model: model,
                    accessToken: token,
                    accountId: accountId,
                    onPartialResponse: onPartialResponse
                )
            } catch let error as OAuthError {
                if let apiKey = provider.apiKey {
                    return try await makeOpenAIChatStreamingRequest(
                        url: URL(string: provider.baseURL)!,
                        model: model,
                        systemMessage: systemMessage,
                        messages: messages,
                        headers: ["Authorization": "Bearer \(apiKey)"],
                        onPartialResponse: onPartialResponse
                    )
                }
                throw EnhancementError.customError(error.errorDescription ?? "OpenAI OAuth error")
            }

        case nil:
            if provider == .gemini && isGeminiSignedIn && provider.apiKey == nil {
                throw EnhancementError.customError("Chat is not yet supported with Gemini OAuth. Please add a Gemini API key to use chat.")
            }
            // Fallback to non-streaming
            let result = try await makeChatRequest(
                provider: provider,
                model: model,
                systemMessage: systemMessage,
                messages: messages
            )
            await onPartialResponse(result)
            return result
        }
    }

    // MARK: - Non-Streaming Chat Request

    /// Multi-turn non-streaming request with explicit provider and model.
    func makeChatRequest(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String {
        switch provider {
        case .anthropic:
            guard let apiKey = provider.apiKey else {
                throw EnhancementError.notConfigured
            }
            return try await makeAnthropicChatNonStreamingRequest(
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                apiKey: apiKey
            )

        case .openAI where isOpenAISignedIn:
            do {
                let oauthProvider = OpenAIOAuthProvider()
                let (token, accountId, _) = try await OAuthManager.shared.validAccessToken(for: oauthProvider)
                return try await OpenAIOAuthClient.chat(
                    systemMessage: systemMessage,
                    messages: messages,
                    model: model,
                    accessToken: token,
                    accountId: accountId
                )
            } catch let error as OAuthError {
                if let apiKey = provider.apiKey {
                    let (url, headers) = (URL(string: provider.baseURL)!, ["Authorization": "Bearer \(apiKey)"])
                    return try await makeOpenAIChatNonStreamingRequest(
                        url: url,
                        model: model,
                        systemMessage: systemMessage,
                        messages: messages,
                        headers: headers
                    )
                }
                throw EnhancementError.customError(error.errorDescription ?? "OpenAI OAuth error")
            }

        default:
            // OpenAI-compatible for all other providers
            let (url, headers) = try await chatRequestConfig(for: provider, model: model)
            return try await makeOpenAIChatNonStreamingRequest(
                url: url,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: headers
            )
        }
    }

    // MARK: - Tool Decision Request

    /// Lets a cloud model decide whether to invoke the implicit cross-note search tool.
    /// Returns the focused query requested by the model, or nil when the model decides
    /// not to use the tool for this turn.
    func makeCrossNoteSearchToolDecision(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String? {
        switch provider {
        case .anthropic:
            guard let apiKey = provider.apiKey else {
                throw EnhancementError.notConfigured
            }
            return try await makeAnthropicCrossNoteSearchToolDecision(
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                apiKey: apiKey
            )

        default:
            let (url, headers) = try await chatRequestConfig(for: provider, model: model)
            return try await makeOpenAICrossNoteSearchToolDecision(
                url: url,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: headers
            )
        }
    }

    /// Lets a cloud model decide whether to invoke the implicit web search tool.
    /// Returns the focused query requested by the model, or nil when the model decides
    /// not to use the tool for this turn.
    func makeWebSearchToolDecision(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        messages: [[String: String]]
    ) async throws -> String? {
        switch provider {
        case .anthropic:
            guard let apiKey = provider.apiKey else {
                throw EnhancementError.notConfigured
            }
            return try await makeAnthropicWebSearchToolDecision(
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                apiKey: apiKey
            )

        default:
            let (url, headers) = try await chatRequestConfig(for: provider, model: model)
            return try await makeOpenAIWebSearchToolDecision(
                url: url,
                model: model,
                systemMessage: systemMessage,
                messages: messages,
                headers: headers
            )
        }
    }

    // MARK: - Private Helpers

    private enum ChatStreamingRoute {
        case anthropic, openAICompatibleCloud, copilot, ollama, customOpenAI, openAIOAuth
    }

    private func chatStreamingRoute(for provider: AIProvider, model: String) -> ChatStreamingRoute? {
        switch provider {
        case .anthropic:
            return provider.apiKey != nil ? .anthropic : nil
        case .ollama:
            return .ollama
        case .customOpenAI:
            return .customOpenAI
        case .copilot:
            return isCopilotSignedIn ? .copilot : nil
        case .openAI:
            if isOpenAISignedIn {
                return .openAIOAuth
            }
            if provider.supportsResponseStreaming(model: model), provider.apiKey != nil {
                return .openAICompatibleCloud
            }
            return nil
        default:
            return provider.supportsResponseStreaming(model: model) && provider.apiKey != nil
                ? .openAICompatibleCloud
                : nil
        }
    }

    private func chatRequestConfig(for provider: AIProvider, model: String) async throws -> (URL, [String: String]) {
        switch provider {
        case .copilot:
            let token = try await CopilotOAuthManager.shared.validCopilotToken()
            guard let url = URL(string: "\(CopilotAPIClient.baseURL)/chat/completions") else {
                throw EnhancementError.customError("Invalid Copilot URL")
            }
            return (url, CopilotAPIClient.chatHeaders(copilotToken: token))

        case .ollama:
            let serverURL = ollamaServerURL
            guard let url = URL(string: "\(serverURL)/v1/chat/completions") else {
                throw EnhancementError.customError("Invalid Ollama server URL")
            }
            return (url, [:])

        case .customOpenAI:
            let endpointURL = customOpenAIRequestURL
            guard !endpointURL.isEmpty, let url = URL(string: endpointURL) else {
                throw EnhancementError.customError("Custom AI endpoint not configured")
            }
            var headers: [String: String] = [:]
            if let apiKey = AIProvider.customOpenAI.apiKey, !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }
            return (url, headers)

        default:
            guard let apiKey = provider.apiKey else {
                throw EnhancementError.notConfigured
            }
            guard let url = URL(string: provider.baseURL) else {
                throw EnhancementError.customError("Invalid URL for \(provider.displayName)")
            }
            return (url, ["Authorization": "Bearer \(apiKey)"])
        }
    }

    private func crossNoteSearchToolSchemaObject() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": crossNoteSearchToolQueryArgumentDescription
                ]
            ],
            "required": ["query"],
            "additionalProperties": false
        ]
    }

    private func webSearchToolSchemaObject() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": webSearchToolQueryArgumentDescription
                ]
            ],
            "required": ["query"],
            "additionalProperties": false
        ]
    }

    // MARK: - OpenAI-Compatible Chat

    private func buildOpenAIChatRequestBody(
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        stream: Bool
    ) -> [String: Any] {
        var allMessages: [[String: Any]] = [
            ["role": "system", "content": systemMessage]
        ]
        for msg in messages {
            allMessages.append(msg as [String: Any])
        }

        var body: [String: Any] = [
            "model": model,
            "messages": allMessages,
            "stream": stream
        ]

        let modelLower = model.lowercased()
        let isReasoningModel = modelLower.hasPrefix("gpt-5")
            || modelLower.hasPrefix("o1")
            || modelLower.hasPrefix("o3")
            || modelLower.hasPrefix("o4")
        if !isReasoningModel {
            body["temperature"] = 0.7
        }

        if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: model) {
            body["reasoning_effort"] = reasoningEffort
        }

        if let extraBody = ReasoningConfig.getExtraBodyParameters(for: model) {
            for (key, value) in extraBody {
                body[key] = value
            }
        }

        return body
    }

    private func makeOpenAIChatStreamingRequest(
        url: URL,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        headers: [String: String],
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let body = buildOpenAIChatRequestBody(model: model, systemMessage: systemMessage, messages: messages, stream: true)
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "AI")
        }

        var aggregatedText = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let delta = Self.openAICompatibleStreamingDelta(from: line) {
                aggregatedText += delta
                await onPartialResponse(aggregatedText)
            }
        }

        guard !aggregatedText.isEmpty else {
            throw EnhancementError.enhancementFailed
        }

        let result = aggregatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = AIEnhancementOutputFilter.filter(result)
        if filtered != aggregatedText {
            await onPartialResponse(filtered)
        }
        return filtered
    }

    private func makeOpenAIChatNonStreamingRequest(
        url: URL,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        headers: [String: String]
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let body = buildOpenAIChatRequestBody(model: model, systemMessage: systemMessage, messages: messages, stream: false)
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "AI")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw EnhancementError.invalidResponse
        }

        return AIEnhancementOutputFilter.filter(content.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func makeOpenAICrossNoteSearchToolDecision(
        url: URL,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        headers: [String: String]
    ) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        var body = buildOpenAIChatRequestBody(
            model: model,
            systemMessage: systemMessage,
            messages: messages,
            stream: false
        )
        body["tools"] = [[
            "type": "function",
            "function": [
                "name": crossNoteSearchToolName,
                "description": crossNoteSearchToolDescription,
                "parameters": crossNoteSearchToolSchemaObject()
            ]
        ]]
        body["tool_choice"] = "auto"

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "AI")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]],
              let toolCall = toolCalls.first,
              let function = toolCall["function"] as? [String: Any],
              let name = function["name"] as? String,
              name == crossNoteSearchToolName,
              let argumentsString = function["arguments"] as? String,
              let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try JSONSerialization.jsonObject(with: argumentsData) as? [String: Any],
              let query = arguments["query"] as? String else {
            return nil
        }

        return normalizedCrossNoteSearchToolQuery(query)
    }

    private func makeOpenAIWebSearchToolDecision(
        url: URL,
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        headers: [String: String]
    ) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        var body = buildOpenAIChatRequestBody(
            model: model,
            systemMessage: systemMessage,
            messages: messages,
            stream: false
        )
        body["tools"] = [[
            "type": "function",
            "function": [
                "name": webSearchToolName,
                "description": webSearchToolDescription,
                "parameters": webSearchToolSchemaObject()
            ]
        ]]
        body["tool_choice"] = "auto"

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "AI")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]],
              let toolCall = toolCalls.first,
              let function = toolCall["function"] as? [String: Any],
              let name = function["name"] as? String,
              name == webSearchToolName,
              let argumentsString = function["arguments"] as? String,
              let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try JSONSerialization.jsonObject(with: argumentsData) as? [String: Any],
              let query = arguments["query"] as? String else {
            return nil
        }

        return normalizedWebSearchToolQuery(query)
    }

    // MARK: - Anthropic Chat

    private func makeAnthropicChatStreamingRequest(
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        apiKey: String,
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        // Anthropic: system is top-level, messages only contain user/assistant
        let anthropicMessages = messages.map { msg -> [String: Any] in
            msg as [String: Any]
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": anthropicMessages,
            "stream": true
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "Anthropic")
        }

        var aggregatedText = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()

            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard !payload.isEmpty,
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
               !text.isEmpty {
                aggregatedText += text
                await onPartialResponse(aggregatedText)
                continue
            }

            if type == "error",
               let error = event["error"] as? [String: Any] {
                let message = (error["message"] as? String) ?? "Anthropic streaming error"
                let errorType = error["type"] as? String
                if errorType == "overloaded_error" {
                    throw EnhancementError.serverError
                }
                throw EnhancementError.customError(message)
            }
        }

        guard !aggregatedText.isEmpty else {
            throw EnhancementError.enhancementFailed
        }

        let result = aggregatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = AIEnhancementOutputFilter.filter(result)
        if filtered != aggregatedText {
            await onPartialResponse(filtered)
        }
        return filtered
    }

    private func makeAnthropicChatNonStreamingRequest(
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        apiKey: String
    ) async throws -> String {
        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": messages.map { $0 as [String: Any] }
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "Anthropic")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw EnhancementError.invalidResponse
        }

        return AIEnhancementOutputFilter.filter(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func makeAnthropicCrossNoteSearchToolDecision(
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        apiKey: String
    ) async throws -> String? {
        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemMessage,
            "messages": messages.map { $0 as [String: Any] },
            "tools": [[
                "name": crossNoteSearchToolName,
                "description": crossNoteSearchToolDescription,
                "input_schema": crossNoteSearchToolSchemaObject()
            ]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "Anthropic")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let toolCall = content.first(where: {
                  ($0["type"] as? String) == "tool_use"
                      && ($0["name"] as? String) == crossNoteSearchToolName
              }),
              let input = toolCall["input"] as? [String: Any],
              let query = input["query"] as? String else {
            return nil
        }

        return normalizedCrossNoteSearchToolQuery(query)
    }

    private func makeAnthropicWebSearchToolDecision(
        model: String,
        systemMessage: String,
        messages: [[String: String]],
        apiKey: String
    ) async throws -> String? {
        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemMessage,
            "messages": messages.map { $0 as [String: Any] },
            "tools": [[
                "name": webSearchToolName,
                "description": webSearchToolDescription,
                "input_schema": webSearchToolSchemaObject()
            ]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw chatHTTPError(statusCode: httpResponse.statusCode, errorString: errorString, provider: "Anthropic")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let toolCall = content.first(where: {
                  ($0["type"] as? String) == "tool_use"
                      && ($0["name"] as? String) == webSearchToolName
              }),
              let input = toolCall["input"] as? [String: Any],
              let query = input["query"] as? String else {
            return nil
        }

        return normalizedWebSearchToolQuery(query)
    }

    // MARK: - Error Helpers

    private func normalizedCrossNoteSearchToolQuery(_ query: String) -> String? {
        let normalized = query
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedWebSearchToolQuery(_ query: String) -> String? {
        let normalized = query
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func chatHTTPError(statusCode: Int, errorString: String, provider: String) -> EnhancementError {
        switch statusCode {
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError
        default:
            return .customError("\(provider) error (HTTP \(statusCode)): \(errorString)")
        }
    }
}
