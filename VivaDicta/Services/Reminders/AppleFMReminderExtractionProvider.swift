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
                userPrompt(noteText: trimmedText)
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

        Only extract genuine reminder-worthy actions, next steps, or commitments that the user is likely to want in Apple Reminders.
        Do not invent tasks.
        Do not invent deadlines.
        The current note is the only source of truth. Never carry over tasks from previous notes or earlier requests.
        Use concise, actionable titles.
        Move supporting detail into notes.
        Never create a reminder whose title is only a date, time, weekday, or scheduling phrase such as 'Saturday at 10 am'.
        A due phrase belongs in the due-date fields of the task it refers to, not as a separate reminder.
        Return at most one reminder per actionable task or commitment in the note.
        When the note includes a specific date, weekday, or relative phrase that can be resolved, you must calculate the exact absolute due date using the current date and time zone.
        Examples of resolvable phrases include 'tomorrow noon', 'Saturday at 9 am', 'next Thursday at 14:00', and 'April 20 at 3 PM'.
        For resolvable phrases, fill optionalDueDateString with an absolute value.
        Prefer ISO 8601 date-time with time zone, such as 2026-04-19T09:00:00+01:00.
        A timezone-less value like 2026-04-19T09:00:00 is acceptable if needed.
        If only the date is known, a date-only value like 2026-04-19 is acceptable.
        Preserve the original due wording in rawDueDatePhrase whenever a due phrase exists, even when you also provide optionalDueDateString.
        If a due phrase is ambiguous, leave the normalized due date nil and preserve the original wording in rawDueDatePhrase.
        If no reminder-worthy tasks exist, return an empty reminders array.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone identifier: \(timeZone.identifier)
        """
    }

    @PromptBuilder
    private func userPrompt(noteText: String) -> Prompt {
        """
        Extract reminder suggestions from the following transcription note.

        <NOTE>
        \(noteText)
        </NOTE>
        """
    }
}
