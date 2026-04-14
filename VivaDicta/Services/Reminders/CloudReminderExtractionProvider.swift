//
//  CloudReminderExtractionProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation
import os

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

private struct CloudReminderDraftsPayload: Codable {
    var reminders: [CloudReminderDraftPayload]
    var summary: String?

    var reminderDraftsResponse: ReminderDraftsResponse {
        ReminderDraftsResponse(
            reminders: reminders.map(\.reminderDraft),
            summary: summary
        )
    }
}

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
        case .ollama:
            return true
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
        timeZone: TimeZone
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
                        timeZone: timeZone
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
                timeZone: timeZone
            )
        case .openAI:
            if aiService.isOpenAISignedIn {
                do {
                    return try await makeOpenAIOAuthRequest(
                        noteText: trimmedText,
                        model: model,
                        now: now,
                        timeZone: timeZone
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
                        timeZone: timeZone
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
                timeZone: timeZone
            )
        case .gemini:
            if aiService.isGeminiSignedIn {
                do {
                    return try await makeGeminiOAuthRequest(
                        noteText: trimmedText,
                        model: model,
                        now: now,
                        timeZone: timeZone
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
                        timeZone: timeZone
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
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        let provider = OpenAIOAuthProvider()
        let (token, accountId, _) = try await OAuthManager.shared.validAccessToken(for: provider)
        let responseText = try await OpenAIOAuthClient.enhance(
            text: textTransportUserMessage(noteText: noteText, now: now, timeZone: timeZone),
            systemPrompt: systemMessage(now: now, timeZone: timeZone),
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
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        let provider = GeminiOAuthProvider()
        let (token, _, projectId) = try await OAuthManager.shared.validAccessToken(for: provider)
        let responseText = try await GeminiAPIClient.enhance(
            text: textTransportUserMessage(noteText: noteText, now: now, timeZone: timeZone),
            systemPrompt: systemMessage(now: now, timeZone: timeZone),
            model: model,
            accessToken: token,
            projectId: projectId
        )
        return try decodeTextResponse(responseText)
    }

    private func makeVivAgentsRequest(
        noteText: String,
        model: String,
        provider: String,
        now: Date,
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        let responseText = try await VivAgentsClient.enhance(
            text: textTransportUserMessage(noteText: noteText, now: now, timeZone: timeZone),
            systemPrompt: systemMessage(now: now, timeZone: timeZone),
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
        timeZone: TimeZone
    ) async throws -> ReminderDraftsResponse {
        logger.logNotice("Reminder extraction - Starting Anthropic structured request model=\(model)")

        var request = URLRequest(url: URL(string: AIProvider.anthropic.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 300

        let schema = reminderSchemaObject()
        let systemMessage = systemMessage(now: now, timeZone: timeZone)
        let userMessage = userMessage(noteText: noteText, now: now, timeZone: timeZone)

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
        timeZone: TimeZone
    ) throws -> [String: Any] {
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemMessage(now: now, timeZone: timeZone)],
            ["role": "user", "content": userMessage(noteText: noteText, now: now, timeZone: timeZone)]
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
                    "schema": reminderSchemaObject()
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

    private func textTransportUserMessage(
        noteText: String,
        now: Date,
        timeZone: TimeZone
    ) -> String {
        """
        \(userMessage(noteText: noteText, now: now, timeZone: timeZone))

        Return only a valid JSON object.
        Do not wrap the JSON in markdown fences.
        Do not add explanations before or after the JSON.
        Use exactly this top-level shape:
        {
          "reminders": [
            {
              "title": "string",
              "dueDateString": "YYYY-MM-DD or null",
              "dueTimeString": "HH:mm or null",
              "rawDueDatePhrase": "string or null",
              "notes": "string or null",
              "priority": "none|low|medium|high"
            }
          ],
          "summary": "string or null"
        }
        """
    }

    private func reminderSchemaObject() -> [String: Any] {
        ReminderDraftsJSONSchema.object
    }

    private func systemMessage(now: Date, timeZone: TimeZone) -> String {
        """
        You extract reminder suggestions from transcription notes.
        Return structured reminder drafts for user review before importing to Apple Reminders.
        Use only the current note as the source of truth.
        Do not invent tasks or deadlines.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone identifier: \(timeZone.identifier)
        """
    }

    private func userMessage(noteText: String, now: Date, timeZone: TimeZone) -> String {
        """
        Extract reminder suggestions from this note.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone: \(timeZone.identifier)

        Rules:
        - Extract only genuine reminder-worthy actions, commitments, or follow-ups that belong in Apple Reminders.
        - Use a concise, actionable title grounded in the note text.
        - Do not create a reminder whose title is only a date, time, weekday, or scheduling phrase.
        - A due phrase belongs in dueDateString, dueTimeString, and rawDueDatePhrase, not in the title.
        - If the note includes a resolvable day, date, or time such as 'tomorrow noon', 'Saturday at 10 a.m.', 'next Thursday at 14:00', or 'April 20 at 3 PM', calculate the exact due date and time using the current date and time zone.
        - Set dueDateString in YYYY-MM-DD format when you can determine the date.
        - Set dueTimeString in HH:mm 24-hour format only when a specific time is mentioned.
        - When a value is missing, use null, not the words 'nil' or 'null'.
        - Preserve the original due wording in rawDueDatePhrase whenever a due phrase exists.
        - If the timing is ambiguous, leave dueDateString and dueTimeString empty and preserve the original wording in rawDueDatePhrase.
        - Return at most one reminder per actionable task.
        - If the note contains no reminder-worthy task, return an empty reminders array.

        Examples of good extraction:
        \(fewShotExamples(now: now, timeZone: timeZone))

        Note:
        \(noteText)
        """
    }

    private func fewShotExamples(now: Date, timeZone: TimeZone) -> String {
        let saturdayAtTen = nextWeekdayDate(
            weekday: 7,
            hour: 10,
            minute: 0,
            now: now,
            timeZone: timeZone
        )

        let sundayAtTen = nextWeekdayDate(
            weekday: 1,
            hour: 10,
            minute: 0,
            now: now,
            timeZone: timeZone
        )

        let fridayDateOnly = nextWeekdayDateOnlyString(
            weekday: 6,
            now: now,
            timeZone: timeZone
        ) ?? "2026-04-17"

        return """
        Example 1
        Note: "Okay, I need to visit the dentist on Saturday at 10 a.m."
        Good response:
        {"reminders":[{"title":"Visit dentist","dueDateString":"\(formattedDateString(from: saturdayAtTen, timeZone: timeZone) ?? "2026-04-18")","dueTimeString":"\(formattedTimeString(from: saturdayAtTen, timeZone: timeZone) ?? "10:00")","rawDueDatePhrase":"Saturday at 10 a.m.","notes":null,"priority":"high"}],"summary":"Found 1 reminder suggestion."}

        Example 2
        Note: "Okay, I need to call my parents on Sunday at 10 a.m."
        Good response:
        {"reminders":[{"title":"Call parents","dueDateString":"\(formattedDateString(from: sundayAtTen, timeZone: timeZone) ?? "2026-04-19")","dueTimeString":"\(formattedTimeString(from: sundayAtTen, timeZone: timeZone) ?? "10:00")","rawDueDatePhrase":"Sunday at 10 a.m.","notes":null,"priority":"high"}],"summary":"Found 1 reminder suggestion."}

        Example 3
        Note: "I have a dinner with my friends this Friday, so please remind me."
        Good response:
        {"reminders":[{"title":"Dinner with friends","dueDateString":"\(fridayDateOnly)","dueTimeString":null,"rawDueDatePhrase":"this Friday","notes":null,"priority":"high"}],"summary":"Found 1 reminder suggestion."}

        Example 4
        Note: "I had coffee and answered emails."
        Good response:
        {"reminders":[],"summary":"No reminder suggestions found."}
        """
    }

    private func nextWeekdayDate(
        weekday: Int,
        hour: Int,
        minute: Int,
        now: Date,
        timeZone: TimeZone
    ) -> Date? {
        let calendar = calendar(timeZone: timeZone)
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = timeZone

        return calendar.nextDate(
            after: now.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func nextWeekdayDateOnlyString(
        weekday: Int,
        now: Date,
        timeZone: TimeZone
    ) -> String? {
        let calendar = calendar(timeZone: timeZone)
        var components = DateComponents()
        components.weekday = weekday
        components.hour = 9
        components.minute = 0
        components.second = 0
        components.timeZone = timeZone

        guard let date = calendar.nextDate(
            after: now.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return nil
        }

        return formattedDateString(from: date, timeZone: timeZone)
    }

    private func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func formattedDateString(from date: Date?, timeZone: TimeZone) -> String? {
        guard let date else { return nil }

        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                timeZone: timeZone,
                calendar: calendar(timeZone: timeZone)
            )
        )
    }

    private func formattedTimeString(from date: Date?, timeZone: TimeZone) -> String? {
        guard let date else { return nil }

        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                timeZone: timeZone,
                calendar: calendar(timeZone: timeZone)
            )
        )
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
