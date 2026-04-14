//
//  ReminderDraft.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

enum ReminderDraftPriority: String, Codable, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high

    var eventKitPriority: Int {
        switch self {
        case .none:
            0
        case .high:
            1
        case .medium:
            5
        case .low:
            9
        }
    }
}

struct ReminderDraft: Codable, Sendable {
    var title: String

    var optionalDueDateString: String?

    var rawDueDatePhrase: String?

    var notes: String?

    var priority: ReminderDraftPriority

    nonisolated init(
        title: String,
        optionalDueDateString: String? = nil,
        rawDueDatePhrase: String? = nil,
        notes: String? = nil,
        priority: ReminderDraftPriority = .none
    ) {
        self.title = title
        self.optionalDueDateString = optionalDueDateString
        self.rawDueDatePhrase = rawDueDatePhrase
        self.notes = notes
        self.priority = priority
    }
}

struct ReminderDraftsResponse: Codable, Sendable {
    var reminders: [ReminderDraft]

    var summary: String?

    nonisolated init(reminders: [ReminderDraft], summary: String? = nil) {
        self.reminders = reminders
        self.summary = summary
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
@Generable(description: "Priority level for an extracted reminder draft.")
enum ReminderDraftPrioritySchema: String, Sendable {
    case none
    case low
    case medium
    case high

    var reminderPriority: ReminderDraftPriority {
        ReminderDraftPriority(rawValue: rawValue) ?? .none
    }
}

@available(iOS 26, *)
@Generable(description: "A reminder draft extracted from a transcription note for user review before importing into Apple Reminders.")
struct ReminderDraftSchema: Sendable {
    @Guide(description: "A concise reminder title grounded in the note text. Keep it short and actionable, and preserve the actual action, person, or object mentioned in the note.")
    var title: String

    @Guide(description: "An optional due date for the reminder in YYYY-MM-DD format. Leave nil if no date is specified or the timing is ambiguous.")
    var dueDateString: String?

    @Guide(description: "An optional due time for the reminder in HH:mm 24-hour format, such as 10:00 or 14:30. Leave nil if no specific time is mentioned.")
    var dueTimeString: String?

    @Guide(description: "The original due date phrase from the note, such as 'tomorrow noon' or 'end of week'. Preserve this whenever a due phrase exists, even if dueDateString or dueTimeString is also set. Leave nil when no due phrase exists.")
    var rawDueDatePhrase: String?

    @Guide(description: "Optional supporting context for the reminder, such as meeting details or follow-up notes. Leave nil if unnecessary.")
    var notes: String?

    @Guide(description: "The reminder priority.")
    var priority: ReminderDraftPrioritySchema

    var reminderDraft: ReminderDraft {
        ReminderDraft(
            title: title,
            optionalDueDateString: combinedDueDateString,
            rawDueDatePhrase: rawDueDatePhrase,
            notes: notes,
            priority: priority.reminderPriority
        )
    }

    private var combinedDueDateString: String? {
        let trimmedDate = dueDateString?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedDate, !trimmedDate.isEmpty else {
            return nil
        }

        let trimmedTime = dueTimeString?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedTime, !trimmedTime.isEmpty else {
            return trimmedDate
        }

        return "\(trimmedDate)T\(trimmedTime):00"
    }
}

@available(iOS 26, *)
@Generable(description: "A structured response containing zero or more reminder drafts extracted from a transcription note.")
struct ReminderDraftsResponseSchema: Sendable {
    @Guide(description: "Reminder drafts that should be shown to the user for review. Return an empty array when the note does not contain reminder-worthy actions.")
    var reminders: [ReminderDraftSchema]

    @Guide(description: "Optional short summary of the extraction result, such as 'Found 2 reminder suggestions'.")
    var summary: String?

    var reminderDraftsResponse: ReminderDraftsResponse {
        ReminderDraftsResponse(
            reminders: reminders.map(\.reminderDraft),
            summary: summary
        )
    }
}
#endif
