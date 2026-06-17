// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os
import AICore

// Thin `AITextProvider` conformances that bind each backend's per-request
// configuration and delegate to the underlying service. The services are
// unchanged; these wrappers normalize naming and config so consumers can treat
// every backend uniformly as `any AITextProvider`.

// MARK: - Anthropic

public struct AnthropicTextProvider: AITextProvider {
    private let service: AnthropicService
    private let apiKey: String
    private let model: String

    public init(networkService: any NetworkService, logger: Logger, baseTimeout: TimeInterval, apiKey: String, model: String) {
        self.service = AnthropicService(networkService: networkService, logger: logger, baseTimeout: baseTimeout)
        self.apiKey = apiKey
        self.model = model
    }

    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await service.enhance(systemMessage: systemMessage, userMessage: userMessage, apiKey: apiKey, model: model)
    }

    public func enhanceStreaming(systemMessage: String, userMessage: String, onPartialResponse: @escaping @MainActor (String) -> Void) async throws -> String {
        try await service.enhanceStreaming(systemMessage: systemMessage, userMessage: userMessage, apiKey: apiKey, model: model, onPartialResponse: onPartialResponse)
    }
}

// MARK: - OpenAI-compatible (OpenAI, Groq, Cerebras, Mistral, xAI, OpenRouter, Z.AI, Kimi, Vercel, HuggingFace)

public struct OpenAICompatibleTextProvider: AITextProvider {
    private let service: OpenAICompatibleService
    private let url: URL
    private let modelName: String
    private let headers: [String: String]
    private let timeout: TimeInterval
    private let errorPrefix: String
    private let notFoundMessage: String?
    private let unauthorizedMessage: String?

    public init(
        networkService: any NetworkService,
        logger: Logger,
        url: URL,
        modelName: String,
        headers: [String: String],
        timeout: TimeInterval,
        errorPrefix: String,
        notFoundMessage: String? = nil,
        unauthorizedMessage: String? = nil
    ) {
        self.service = OpenAICompatibleService(networkService: networkService, logger: logger)
        self.url = url
        self.modelName = modelName
        self.headers = headers
        self.timeout = timeout
        self.errorPrefix = errorPrefix
        self.notFoundMessage = notFoundMessage
        self.unauthorizedMessage = unauthorizedMessage
    }

    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await service.enhance(url: url, modelName: modelName, systemMessage: systemMessage, userMessage: userMessage, headers: headers, timeout: timeout)
    }

    public func enhanceStreaming(systemMessage: String, userMessage: String, onPartialResponse: @escaping @MainActor (String) -> Void) async throws -> String {
        try await service.enhanceStreaming(
            url: url,
            modelName: modelName,
            systemMessage: systemMessage,
            userMessage: userMessage,
            headers: headers,
            timeout: timeout,
            errorPrefix: errorPrefix,
            notFoundMessage: notFoundMessage,
            unauthorizedMessage: unauthorizedMessage,
            onPartialResponse: onPartialResponse
        )
    }
}

// MARK: - Apple Foundation Model (on-device, iOS/macOS 26+)

@available(iOS 26, macOS 26, *)
public struct AppleFMTextProvider: AITextProvider {
    private let samplingProfile: AppleFoundationModelSamplingProfile

    public init(samplingProfile: AppleFoundationModelSamplingProfile) {
        self.samplingProfile = samplingProfile
    }

    // AppleFoundationModelService is @MainActor, so it's constructed inside the
    // async calls (which hop to the main actor) rather than in this nonisolated init.
    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await AppleFoundationModelService().enhance(systemMessage: systemMessage, userMessage: userMessage, samplingProfile: samplingProfile)
    }

    public func enhanceStreaming(systemMessage: String, userMessage: String, onPartialResponse: @escaping @MainActor (String) -> Void) async throws -> String {
        try await AppleFoundationModelService().enhanceStreaming(systemMessage: systemMessage, userMessage: userMessage, samplingProfile: samplingProfile, onPartialResponse: onPartialResponse)
    }
}

// MARK: - Gemini (OAuth). Maps systemMessage -> systemPrompt, userMessage -> text.

public struct GeminiTextProvider: AITextProvider {
    private let model: String
    private let accessToken: String
    private let projectId: String?
    private let networkService: any NetworkService

    public init(model: String, accessToken: String, projectId: String?, networkService: any NetworkService) {
        self.model = model
        self.accessToken = accessToken
        self.projectId = projectId
        self.networkService = networkService
    }

    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await GeminiAPIClient.enhance(text: userMessage, systemPrompt: systemMessage, model: model, accessToken: accessToken, projectId: projectId, networkService: networkService)
    }

    public func enhanceStreaming(systemMessage: String, userMessage: String, onPartialResponse: @escaping @MainActor (String) -> Void) async throws -> String {
        try await GeminiAPIClient.enhanceStreaming(text: userMessage, systemPrompt: systemMessage, model: model, accessToken: accessToken, projectId: projectId, onPartialResult: onPartialResponse, networkService: networkService)
    }
}

// MARK: - GitHub Copilot (OAuth). Maps systemMessage -> systemPrompt, userMessage -> text.

public struct CopilotTextProvider: AITextProvider {
    private let model: String
    private let copilotToken: String

    public init(model: String, copilotToken: String) {
        self.model = model
        self.copilotToken = copilotToken
    }

    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await CopilotAPIClient.enhance(text: userMessage, systemPrompt: systemMessage, model: model, copilotToken: copilotToken)
    }

    public func enhanceStreaming(systemMessage: String, userMessage: String, onPartialResponse: @escaping @MainActor (String) -> Void) async throws -> String {
        try await CopilotAPIClient.enhanceStreaming(text: userMessage, systemPrompt: systemMessage, model: model, copilotToken: copilotToken, onPartialResult: onPartialResponse)
    }
}

// MARK: - OpenAI (OAuth). Maps systemMessage -> systemPrompt, userMessage -> text.

public struct OpenAIOAuthTextProvider: AITextProvider {
    private let model: String
    private let accessToken: String
    private let accountId: String?

    public init(model: String, accessToken: String, accountId: String?) {
        self.model = model
        self.accessToken = accessToken
        self.accountId = accountId
    }

    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await OpenAIOAuthClient.enhance(text: userMessage, systemPrompt: systemMessage, model: model, accessToken: accessToken, accountId: accountId)
    }

    public func enhanceStreaming(systemMessage: String, userMessage: String, onPartialResponse: @escaping @MainActor (String) -> Void) async throws -> String {
        try await OpenAIOAuthClient.enhance(text: userMessage, systemPrompt: systemMessage, model: model, accessToken: accessToken, accountId: accountId, onPartialResult: onPartialResponse)
    }
}
