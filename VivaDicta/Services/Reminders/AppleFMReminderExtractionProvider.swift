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
        timeZone: TimeZone
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
            instructions: systemPrompt(now: now, timeZone: timeZone)
        )

        do {
            let response = try await session.respond(
                generating: ReminderDraftsResponseSchema.self,
                options: GenerationOptions(sampling: .greedy)
            ) {
                userPrompt(noteText: trimmedText, now: now, timeZone: timeZone)
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

    private func systemPrompt(now: Date, timeZone: TimeZone) -> String {
        """
        You extract reminder suggestions from transcription notes.
        Return structured reminder drafts for user review before importing to Apple Reminders.
        Use only the current note as the source of truth.
        Do not invent tasks or deadlines.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone identifier: \(timeZone.identifier)
        """
    }

    @PromptBuilder
    private func userPrompt(noteText: String, now: Date, timeZone: TimeZone) -> Prompt {
        """
        Extract reminder suggestions from this note.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone: \(timeZone.identifier)

        Rules:
        - Extract only genuine reminder-worthy actions, next steps, or commitments that the user is likely to want in Apple Reminders.
        - Use a concise, actionable title grounded in the note text.
        - Do not create a reminder whose title is only a date, time, weekday, or scheduling phrase.
        - A due phrase belongs in optionalDueDateString and rawDueDatePhrase, not in the title.
        - If the note includes a resolvable date or time such as 'tomorrow noon', 'Saturday at 10 a.m.', 'next Thursday at 14:00', or 'April 20 at 3 PM', calculate the exact absolute due date.
        - Prefer ISO 8601 date-time with time zone such as 2026-04-19T10:00:00+01:00.
        - A timezone-less value like 2026-04-19T10:00:00 is acceptable if needed.
        - If only the date is known, a date-only value like 2026-04-19 is acceptable.
        - Preserve the original due wording in rawDueDatePhrase whenever a due phrase exists.
        - If the timing is ambiguous, leave optionalDueDateString empty and preserve the original wording in rawDueDatePhrase.
        - Return at most one reminder per actionable task.
        - If the note contains no reminder-worthy task, return an empty reminders array.

        Examples of good extraction:
        \(fewShotExamples(now: now, timeZone: timeZone))

        Note:
        \(noteText)
        """
    }

    private func fewShotExamples(now: Date, timeZone: TimeZone) -> String {
        let saturdayAtTen = nextWeekdayDateString(
            weekday: 7,
            hour: 10,
            minute: 0,
            now: now,
            timeZone: timeZone
        ) ?? "2026-04-18T10:00:00+01:00"

        let sundayAtTen = nextWeekdayDateString(
            weekday: 1,
            hour: 10,
            minute: 0,
            now: now,
            timeZone: timeZone
        ) ?? "2026-04-19T10:00:00+01:00"

        let fridayDateOnly = nextWeekdayDateOnlyString(
            weekday: 6,
            now: now,
            timeZone: timeZone
        ) ?? "2026-04-17"

        return """
        Example 1
        Note: "Okay, I need to visit the dentist on Saturday at 10 a.m."
        Good response:
        {"reminders":[{"title":"Visit dentist","optionalDueDateString":"\(saturdayAtTen)","rawDueDatePhrase":"Saturday at 10 a.m.","notes":null,"priority":"high"}],"summary":"Found 1 reminder suggestion."}

        Example 2
        Note: "Okay, I need to call my parents on Sunday at 10 a.m."
        Good response:
        {"reminders":[{"title":"Call parents","optionalDueDateString":"\(sundayAtTen)","rawDueDatePhrase":"Sunday at 10 a.m.","notes":null,"priority":"high"}],"summary":"Found 1 reminder suggestion."}

        Example 3
        Note: "I have a dinner with my friends this Friday, so please remind me."
        Good response:
        {"reminders":[{"title":"Dinner with friends","optionalDueDateString":"\(fridayDateOnly)","rawDueDatePhrase":"this Friday","notes":null,"priority":"high"}],"summary":"Found 1 reminder suggestion."}

        Example 4
        Note: "I had coffee and answered emails."
        Good response:
        {"reminders":[],"summary":"No reminder suggestions found."}
        """
    }

    private func nextWeekdayDateString(
        weekday: Int,
        hour: Int,
        minute: Int,
        now: Date,
        timeZone: TimeZone
    ) -> String? {
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

        return date.ISO8601Format()
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
}
