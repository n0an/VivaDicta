//
//  CloudReminderExtractionProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation
import Networking
import os
import OAuth
import AICore
import AIProviders

private struct CloudReminderDraftPayload: Codable {
    var title: String
    var dueDateString: String?
    var dueTimeString: String?
    var rawDueDatePhrase: String?
    var notes: String?
    var priority: ReminderDraftPriority

    var reminderDraft: ReminderDraft {
        ReminderDraft(
            title: title,
            optionalDueDateString: combinedDueDateString,
            rawDueDatePhrase: sanitizedOptionalString(rawDueDatePhrase),
            notes: sanitizedOptionalString(notes),
            priority: priority
        )
    }

    private var combinedDueDateString: String? {
        let trimmedDate = sanitizedOptionalString(dueDateString)
        guard let trimmedDate, !trimmedDate.isEmpty else {
            return nil
        }

        let trimmedTime = sanitizedOptionalString(dueTimeString)
        guard let trimmedTime, !trimmedTime.isEmpty else {
            return trimmedDate
        }

        return "\(trimmedDate)T\(trimmedTime):00"
    }

    private func sanitizedOptionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        switch trimmed.lowercased() {
        case "nil", "null", "none":
            return nil
        default:
            return trimmed
        }
    }
}

private struct CloudCalendarEventPayload: Codable {
    var title: String
    var startDateString: String?
    var startTimeString: String?
    var endTimeString: String?
    var isAllDay: Bool?
    var location: String?
    var rawDatePhrase: String?
    var notes: String?

    var calendarEventDraft: CalendarEventDraft {
        let allDay = isAllDay ?? false
        return CalendarEventDraft(
            title: title,
            startDateString: CalendarEventDraftFields.combined(
                date: startDateString,
                time: allDay ? nil : startTimeString
            ),
            endDateString: CalendarEventDraftFields.combined(
                date: startDateString,
                time: allDay ? nil : endTimeString
            ),
            isAllDay: allDay,
            location: CalendarEventDraftFields.sanitized(location),
            rawDatePhrase: CalendarEventDraftFields.sanitized(rawDatePhrase),
            notes: CalendarEventDraftFields.sanitized(notes)
        )
    }
}

private struct CloudReminderDraftsPayload: Codable {
    var reminders: [CloudReminderDraftPayload]
    var events: [CloudCalendarEventPayload]?
    var summary: String?

    var reminderDraftsResponse: ReminderDraftsResponse {
        ReminderDraftsResponse(
            reminders: reminders.map(\.reminderDraft),
            events: (events ?? []).map(\.calendarEventDraft),
            summary: summary
        )
    }
}

final class CloudReminderExtractionProvider {
    private let logger = Logger(category: .reminderExtraction)
    private let aiService: AIService
    private let networkService: any NetworkService

    init(aiService: AIService, networkService: any NetworkService = DefaultNetworkService(category: "CloudReminderExtraction")) {
        self.aiService = aiService
        self.networkService = networkService
    }

    func canExtract(
        provider: AIProvider,
        model: String
    ) -> Bool {
        switch provider {
        case .apple:
            return false
        case .ollama:
            return true
        case .ollamaCloud:
            // Reminder extraction sends `response_format: json_schema`, which
            // Ollama Cloud does not support (only local Ollama does).
            // https://docs.ollama.com/capabilities/structured-outputs
            return false
        case .customOpenAI:
            return !aiService.customOpenAIEndpointURL.isEmpty && !aiService.customOpenAIModelName.isEmpty
        case .copilot:
            return false
        default:
            return aiService.connectedProviders.contains(provider)
        }
    }

    func extract(
        noteText: String,
        provider: AIProvider,
        model: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
    ) async throws -> ReminderDraftsResponse {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return ReminderDraftsResponse(reminders: [])
        }

        switch provider {
        case .anthropic:
            if VivAgentsClient.isEnabled && VivAgentsClient.isAnthropicCliActive {
                do {
                    return try await makeVivAgentsRequest(
                        noteText: trimmedText,
                        model: model,
                        provider: "anthropic",
                        now: now,
                        timeZone: timeZone,
                        language: language,
                        includeEvents: includeEvents
                    )
                } catch {
                    if provider.apiKey != nil {
                        logger.logWarning("Reminder extraction - Anthropic CLI failed, falling back to API key: \(error.localizedDescription)")
                    } else {
                        throw error
                    }
                }
            }

            return try await makeAnthropicRequest(
                noteText: trimmedText,
                model: model,
                apiKey: try apiKey(for: provider),
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            )
        case .openAI:
            if aiService.isOpenAISignedIn {
                do {
                    return try await makeOpenAIOAuthRequest(
                        noteText: trimmedText,
                        model: model,
                        now: now,
                        timeZone: timeZone,
                        language: language,
                        includeEvents: includeEvents
                    )
                } catch {
                    if (VivAgentsClient.isEnabled && VivAgentsClient.isCodexCliActive) || provider.apiKey != nil {
                        logger.logWarning("Reminder extraction - OpenAI OAuth failed, falling back: \(error.localizedDescription)")
                    } else {
                        throw error
                    }
                }
            }

            if VivAgentsClient.isEnabled && VivAgentsClient.isCodexCliActive {
                do {
                    return try await makeVivAgentsRequest(
                        noteText: trimmedText,
                        model: model,
                        provider: "codex",
                        now: now,
                        timeZone: timeZone,
                        language: language,
                        includeEvents: includeEvents
                    )
                } catch {
                    if provider.apiKey != nil {
                        logger.logWarning("Reminder extraction - Codex CLI failed, falling back to API key: \(error.localizedDescription)")
                    } else {
                        throw error
                    }
                }
            }

            let requestConfig = try requestConfiguration(for: provider)
            return try await makeOpenAICompatibleRequest(
                noteText: trimmedText,
                provider: provider,
                model: model,
                url: requestConfig.url,
                headers: requestConfig.headers,
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            )
        case .gemini:
            if aiService.isGeminiSignedIn {
                do {
                    return try await makeGeminiOAuthRequest(
                        noteText: trimmedText,
                        model: model,
                        now: now,
                        timeZone: timeZone,
                        language: language,
                        includeEvents: includeEvents
                    )
                } catch {
                    if (VivAgentsClient.isEnabled && VivAgentsClient.isGeminiCliActive) || provider.apiKey != nil {
                        logger.logWarning("Reminder extraction - Gemini OAuth failed, falling back: \(error.localizedDescription)")
                    } else {
                        throw error
                    }
                }
            }

            if VivAgentsClient.isEnabled && VivAgentsClient.isGeminiCliActive {
                do {
                    return try await makeVivAgentsRequest(
                        noteText: trimmedText,
                        model: model,
                        provider: "gemini",
                        now: now,
                        timeZone: timeZone,
                        language: language,
                        includeEvents: includeEvents
                    )
                } catch {
                    if provider.apiKey != nil {
                        logger.logWarning("Reminder extraction - Gemini CLI failed, falling back to API key: \(error.localizedDescription)")
                    } else {
                        throw error
                    }
                }
            }

            let requestConfig = try requestConfiguration(for: provider)
            return try await makeOpenAICompatibleRequest(
                noteText: trimmedText,
                provider: provider,
                model: model,
                url: requestConfig.url,
                headers: requestConfig.headers,
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
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
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
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
            let endpointURL = aiService.customOpenAIRequestURL
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
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
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
            timeZone: timeZone,
            language: language,
            includeEvents: includeEvents
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

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
            let response = try JSONDecoder().decode(CloudReminderDraftsPayload.self, from: contentData)
            logger.logNotice("Reminder extraction - Structured cloud request completed provider=\(provider.rawValue)")
            return response.reminderDraftsResponse
        } catch {
            logger.logError("Reminder extraction - Failed to decode structured cloud response: \(error.localizedDescription)")
            throw ReminderExtractionError.invalidResponse
        }
    }

    private func makeOpenAIOAuthRequest(
        noteText: String,
        model: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
    ) async throws -> ReminderDraftsResponse {
        let provider = OpenAIOAuthProvider()
        let (token, accountId, _) = try await aiService.oauthManager.validAccessToken(for: provider)
        let responseText = try await OpenAIOAuthClient.enhance(
            text: ReminderExtractionPrompts.textTransportUserMessage(
                noteText: noteText,
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            ),
            systemPrompt: ReminderExtractionPrompts.systemMessage(
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            ),
            model: model,
            accessToken: token,
            accountId: accountId
        )
        return try decodeTextResponse(responseText)
    }

    private func makeGeminiOAuthRequest(
        noteText: String,
        model: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
    ) async throws -> ReminderDraftsResponse {
        let provider = GeminiOAuthProvider()
        let (token, _, projectId) = try await aiService.oauthManager.validAccessToken(for: provider)
        let responseText = try await GeminiAPIClient.enhance(
            text: ReminderExtractionPrompts.textTransportUserMessage(
                noteText: noteText,
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            ),
            systemPrompt: ReminderExtractionPrompts.systemMessage(
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            ),
            model: model,
            accessToken: token,
            projectId: projectId,
            networkService: networkService
        )
        return try decodeTextResponse(responseText)
    }

    private func makeVivAgentsRequest(
        noteText: String,
        model: String,
        provider: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
    ) async throws -> ReminderDraftsResponse {
        let responseText = try await VivAgentsClient.enhance(
            text: ReminderExtractionPrompts.textTransportUserMessage(
                noteText: noteText,
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            ),
            systemPrompt: ReminderExtractionPrompts.systemMessage(
                now: now,
                timeZone: timeZone,
                language: language,
                includeEvents: includeEvents
            ),
            model: model,
            provider: provider
        )
        return try decodeTextResponse(responseText)
    }

    private func makeAnthropicRequest(
        noteText: String,
        model: String,
        apiKey: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
    ) async throws -> ReminderDraftsResponse {
        logger.logNotice("Reminder extraction - Starting Anthropic structured request model=\(model)")

        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        let schema = ReminderDraftsJSONSchema.object(includeEvents: includeEvents)
        let systemMessage = ReminderExtractionPrompts.systemMessage(
            now: now,
            timeZone: timeZone,
            language: language,
            includeEvents: includeEvents
        )
        let userMessage = ReminderExtractionPrompts.userMessage(
            noteText: noteText,
            now: now,
            timeZone: timeZone,
            language: language,
            includeEvents: includeEvents
        )

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

        let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

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
            let response = try JSONDecoder().decode(CloudReminderDraftsPayload.self, from: inputData)
            logger.logNotice("Reminder extraction - Anthropic structured request completed model=\(model)")
            return response.reminderDraftsResponse
        } catch {
            logger.logError("Reminder extraction - Failed to decode Anthropic tool payload: \(error.localizedDescription)")
            throw ReminderExtractionError.invalidResponse
        }
    }

    private func buildOpenAICompatibleRequestBody(
        model: String,
        noteText: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool
    ) throws -> [String: Any] {
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": ReminderExtractionPrompts.systemMessage(
                    now: now,
                    timeZone: timeZone,
                    language: language,
                    includeEvents: includeEvents
                )
            ],
            [
                "role": "user",
                "content": ReminderExtractionPrompts.userMessage(
                    noteText: noteText,
                    now: now,
                    timeZone: timeZone,
                    language: language,
                    includeEvents: includeEvents
                )
            ]
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
                    "schema": ReminderDraftsJSONSchema.object(includeEvents: includeEvents)
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

    private func apiKey(for provider: AIProvider) throws -> String {
        guard let apiKey = provider.apiKey, !apiKey.isEmpty else {
            throw ReminderExtractionError.providerUnavailable(
                "Add an API key for \(provider.displayName) to use cloud reminder extraction."
            )
        }
        return apiKey
    }

    private func decodeTextResponse(_ text: String) throws -> ReminderDraftsResponse {
        for candidate in candidateJSONPayloads(from: text) {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let response = try? JSONDecoder().decode(CloudReminderDraftsPayload.self, from: data) {
                return response.reminderDraftsResponse
            }
        }

        logger.logError("Reminder extraction - Failed to decode text transport response: \(text)")
        throw ReminderExtractionError.invalidResponse
    }

    private func candidateJSONPayloads(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = [trimmed]

        if trimmed.hasPrefix("```"), trimmed.hasSuffix("```") {
            let lines = trimmed.components(separatedBy: .newlines)
            if lines.count >= 3 {
                let unfenced = lines.dropFirst().dropLast().joined(separator: "\n")
                candidates.append(unfenced.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            let object = String(trimmed[start...end])
            candidates.append(object)
        }

        var uniqueCandidates: [String] = []
        for candidate in candidates where !candidate.isEmpty {
            if uniqueCandidates.contains(candidate) == false {
                uniqueCandidates.append(candidate)
            }
        }
        return uniqueCandidates
    }
}
