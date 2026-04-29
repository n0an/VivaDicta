//
//  AppleFMReminderExtractionProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation
import FoundationModels
import os

@available(iOS 26, *)
@MainActor
final class AppleFMReminderExtractionProvider {
    private let logger = Logger(category: .reminderExtraction)

    func extract(
        noteText: String,
        now: Date,
        timeZone: TimeZone,
        language: String?
    ) async throws -> ReminderDraftsResponse {
        guard AppleFoundationModelAvailability.isAvailable else {
            throw ReminderExtractionError.appleFoundationModelUnavailable
        }

        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return ReminderDraftsResponse(reminders: [])
        }

        logger.logNotice("Reminder extraction - Starting Apple Foundation Models request")

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(
            model: model,
            instructions: systemPrompt(now: now, timeZone: timeZone, language: language)
        )

        do {
            let response = try await session.respond(
                generating: ReminderDraftsResponseSchema.self,
                options: GenerationOptions(sampling: .greedy)
            ) {
                userPrompt(noteText: trimmedText, now: now, timeZone: timeZone, language: language)
            }

            logger.logNotice("Reminder extraction - Apple Foundation Models request completed")
            return response.content.reminderDraftsResponse
        } catch let error as LanguageModelSession.GenerationError {
            logger.logError("Reminder extraction - Apple generation error: \(error.localizedDescription)")

            switch error {
            case .guardrailViolation:
                throw ReminderExtractionError.appleGuardrailViolation
            case .refusal:
                throw ReminderExtractionError.appleRefusal
            default:
                throw ReminderExtractionError.extractionFailed(error.localizedDescription)
            }
        } catch {
            logger.logError("Reminder extraction - Apple unexpected error: \(error.localizedDescription)")
            throw ReminderExtractionError.extractionFailed(error.localizedDescription)
        }
    }

    private func systemPrompt(now: Date, timeZone: TimeZone, language: String?) -> String {
        let languageHint = language.map {
            "\nSource note language: \($0). Write title, notes, and rawDueDatePhrase in this language."
        } ?? ""
        return """
        You extract reminder suggestions from transcription notes.
        Return structured reminder drafts for user review before importing to Apple Reminders.
        Use only the current note as the source of truth.
        Do not invent tasks or deadlines.
        Always preserve the source-note language in the human-readable fields (title, notes, rawDueDatePhrase). Do not translate to another language. Field names and enum values stay in English.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone identifier: \(timeZone.identifier)\(languageHint)
        """
    }

    @PromptBuilder
    private func userPrompt(noteText: String, now: Date, timeZone: TimeZone, language: String?) -> Prompt {
        let languageHint = language.map {
            "Source note language: \($0). Write title, notes, and rawDueDatePhrase in this language.\n\n"
        } ?? ""
        """
        Extract reminder suggestions from this note.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone: \(timeZone.identifier)

        \(languageHint)Rules:
        - Extract only genuine reminder-worthy actions, next steps, or commitments that the user is likely to want in Apple Reminders.
        - Use a concise, actionable title grounded in the note text.
        - Always write `title`, `notes`, and `rawDueDatePhrase` in the same language as the Note. If the Note is in German, write them in German; if Russian, in Russian; if French, in French. Never translate to English or any other language. Field names and enum values (priority: none|low|medium|high) stay in English.
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

        Examples of good extraction (English shown for format only - your output language must match the Note):
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

        guard let date = calendar.nextDate(
            after: now.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return nil
        }

        return date
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

        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                timeZone: timeZone,
                calendar: calendar
            )
        )
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
}
