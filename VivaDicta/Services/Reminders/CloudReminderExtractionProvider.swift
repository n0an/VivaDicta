//
//  CloudReminderExtractionProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation
import os

@available(iOS 26, *)
final class CloudReminderExtractionProvider {
    private let logger = Logger(category: .reminderExtraction)
    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    func canExtract(
        provider: AIProvider,
        model: String
    ) -> Bool {
        switch provider {
        case .apple:
            return false
        case .anthropic:
            return provider.apiKey != nil
        case .ollama:
            return true
        case .customOpenAI:
            return !aiService.customOpenAIEndpointURL.isEmpty && !aiService.customOpenAIModelName.isEmpty
        case .copilot:
            return false
        default:
            return provider.apiKey != nil
        }
    }

    func extract(
        noteText: String,
        provider: AIProvider,
        model: String,
        now: Date,
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return ReminderDraftsResponse(reminders: [])
        }

        switch provider {
        case .anthropic:
            return try await makeAnthropicRequest(
                noteText: trimmedText,
                model: model,
                apiKey: try apiKey(for: provider),
                now: now,
                timeZone: timeZone
            )
        case .copilot:
            throw ReminderExtractionError.providerUnavailable(
                "Structured reminder extraction is not supported with GitHub Copilot yet."
            )
        default:
            let requestConfig = try requestConfiguration(for: provider)
            return try await makeOpenAICompatibleRequest(
                noteText: trimmedText,
                provider: provider,
                model: model,
                url: requestConfig.url,
                headers: requestConfig.headers,
                now: now,
                timeZone: timeZone
            )
        }
    }

    private func requestConfiguration(for provider: AIProvider) throws -> (url: URL, headers: [String: String]) {
        switch provider {
        case .ollama:
            guard let url = URL(string: "\(aiService.ollamaServerURL)/v1/chat/completions") else {
                throw ReminderExtractionError.providerUnavailable("Invalid Ollama server URL.")
            }
            return (url, [:])
        case .customOpenAI:
            let endpointURL = aiService.customOpenAIEndpointURL
            guard !endpointURL.isEmpty,
                  let url = URL(string: endpointURL) else {
                throw ReminderExtractionError.providerUnavailable("Custom AI endpoint URL is not configured.")
            }

            var headers: [String: String] = [:]
            if let apiKey = AIProvider.customOpenAI.apiKey, !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }
            return (url, headers)
        case .apple, .anthropic, .copilot:
            throw ReminderExtractionError.providerUnavailable("Unsupported reminder extraction provider: \(provider.displayName).")
        default:
            guard let url = URL(string: provider.baseURL) else {
                throw ReminderExtractionError.providerUnavailable("Invalid URL for \(provider.displayName).")
            }
            return (url, ["Authorization": "Bearer \(try apiKey(for: provider))"])
        }
    }

    private func makeOpenAICompatibleRequest(
        noteText: String,
        provider: AIProvider,
        model: String,
        url: URL,
        headers: [String: String],
        now: Date,
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        logger.logNotice("Reminder extraction - Starting structured cloud request provider=\(provider.rawValue) model=\(model)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let requestBody = try buildOpenAICompatibleRequestBody(
            model: model,
            noteText: noteText,
            now: now,
            timeZone: timeZone
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReminderExtractionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ReminderExtractionError.providerUnavailable(
                "\(provider.displayName) reminder extraction failed (HTTP \(httpResponse.statusCode)): \(errorString)"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw ReminderExtractionError.invalidResponse
        }

        do {
            let response = try JSONDecoder().decode(ReminderDraftsResponse.self, from: contentData)
            logger.logNotice("Reminder extraction - Structured cloud request completed provider=\(provider.rawValue)")
            return response
        } catch {
            logger.logError("Reminder extraction - Failed to decode structured cloud response: \(error.localizedDescription)")
            throw ReminderExtractionError.invalidResponse
        }
    }

    private func makeAnthropicRequest(
        noteText: String,
        model: String,
        apiKey: String,
        now: Date,
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        logger.logNotice("Reminder extraction - Starting Anthropic structured request model=\(model)")

        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        let schema = try reminderSchemaObject()
        let systemMessage = systemMessage(now: now, timeZone: timeZone)
        let userMessage = userMessage(noteText: noteText)

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemMessage,
            "messages": [
                ["role": "user", "content": userMessage]
            ],
            "tools": [
                [
                    "name": "return_reminder_drafts",
                    "description": "Return reminder drafts extracted from the note using the provided schema.",
                    "input_schema": schema
                ]
            ],
            "tool_choice": [
                "type": "tool",
                "name": "return_reminder_drafts"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReminderExtractionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ReminderExtractionError.providerUnavailable(
                "Anthropic reminder extraction failed (HTTP \(httpResponse.statusCode)): \(errorString)"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let toolCall = content.first(where: { ($0["type"] as? String) == "tool_use" }),
              let input = toolCall["input"] as? [String: Any] else {
            throw ReminderExtractionError.invalidResponse
        }

        let inputData = try JSONSerialization.data(withJSONObject: input)
        do {
            let response = try JSONDecoder().decode(ReminderDraftsResponse.self, from: inputData)
            logger.logNotice("Reminder extraction - Anthropic structured request completed model=\(model)")
            return response
        } catch {
            logger.logError("Reminder extraction - Failed to decode Anthropic tool payload: \(error.localizedDescription)")
            throw ReminderExtractionError.invalidResponse
        }
    }

    private func buildOpenAICompatibleRequestBody(
        model: String,
        noteText: String,
        now: Date,
        timeZone: TimeZone
    ) throws -> [String: Any] {
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemMessage(now: now, timeZone: timeZone)],
            ["role": "user", "content": userMessage(noteText: noteText)]
        ]

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "reminder_drafts_response",
                    "strict": true,
                    "schema": try reminderSchemaObject()
                ]
            ]
        ]

        if model.lowercased().hasPrefix("gpt-5") == false {
            requestBody["temperature"] = 0.2
        }

        if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: model) {
            requestBody["reasoning_effort"] = reasoningEffort
        }

        if let extraBody = ReasoningConfig.getExtraBodyParameters(for: model) {
            for (key, value) in extraBody {
                requestBody[key] = value
            }
        }

        return requestBody
    }

    private func reminderSchemaObject() throws -> [String: Any] {
        let data = try JSONEncoder().encode(ReminderDraftsResponseSchema.generationSchema)
        guard var schema = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ReminderExtractionError.invalidResponse
        }
        sanitizeSchema(&schema)
        return schema
    }

    private func sanitizeSchema(_ value: inout [String: Any]) {
        value.removeValue(forKey: "x-order")
        for (key, child) in value {
            if var childDictionary = child as? [String: Any] {
                sanitizeSchema(&childDictionary)
                value[key] = childDictionary
            } else if var childArray = child as? [[String: Any]] {
                for index in childArray.indices {
                    sanitizeSchema(&childArray[index])
                }
                value[key] = childArray
            }
        }
    }

    private func systemMessage(now: Date, timeZone: TimeZone) -> String {
        """
        You extract reminder suggestions from transcription notes.

        Only extract genuine reminder-worthy actions, commitments, or follow-ups that belong in Apple Reminders.
        Do not invent tasks.
        Do not invent deadlines.
        Use concise, actionable titles.
        Put supporting detail into notes.
        If timing is ambiguous, keep optionalDueDateString null and preserve the original wording in rawDueDatePhrase.
        If no reminder-worthy tasks exist, return an empty reminders array.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone identifier: \(timeZone.identifier)
        """
    }

    private func userMessage(noteText: String) -> String {
        """
        Extract reminder suggestions from the following transcription note.

        <NOTE>
        \(noteText)
        </NOTE>
        """
    }

    private func apiKey(for provider: AIProvider) throws -> String {
        guard let apiKey = provider.apiKey, !apiKey.isEmpty else {
            throw ReminderExtractionError.providerUnavailable(
                "Add an API key for \(provider.displayName) to use cloud reminder extraction."
            )
        }
        return apiKey
    }
}
