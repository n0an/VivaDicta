//
//  ReminderDraftsJSONSchema.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

enum ReminderDraftsJSONSchema {
    /// The response schema. `includeEvents` adds the calendar half - left out
    /// entirely when calendar extraction is off, so the model is never asked
    /// for something the user does not want.
    static func object(includeEvents: Bool) -> [String: Any] {
        var properties: [String: Any] = [
            "reminders": [
                "type": "array",
                "description": "Reminder drafts that should be shown to the user for review. Return an empty array when the note does not contain reminder-worthy actions.",
                "items": reminderDraftObject
            ],
            "summary": nullableString(
                description: "Optional short summary of the extraction result, such as 'Found 2 reminder suggestions'."
            )
        ]
        var required = ["reminders", "summary"]

        if includeEvents {
            properties["events"] = [
                "type": "array",
                "description": "Calendar events found in the note - things that happen at a set time and that the user attends. Return an empty array when the note contains none.",
                "items": calendarEventObject
            ]
            required.insert("events", at: 1)
        }

        return [
            "type": "object",
            "additionalProperties": false,
            "properties": properties,
            "required": required
        ]
    }

    private static let reminderDraftObject: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "title": [
                "type": "string",
                "description": "A concise reminder title grounded in the note text. Keep it short and actionable, and preserve the actual action, person, or object mentioned in the note."
            ],
            "dueDateString": nullableString(
                description: "An optional due date for the reminder in YYYY-MM-DD format. Leave it null when no date is specified or the timing is ambiguous."
            ),
            "dueTimeString": nullableString(
                description: "An optional due time for the reminder in HH:mm 24-hour format, such as 10:00 or 14:30. Leave it null when no specific time is mentioned."
            ),
            "rawDueDatePhrase": nullableString(
                description: "The original due date phrase from the note, such as 'tomorrow noon' or 'end of week'. Preserve this whenever a due phrase exists, even if dueDateString or dueTimeString is also set. Use null when no due phrase exists."
            ),
            "notes": nullableString(
                description: "Optional supporting context for the reminder, such as meeting details or follow-up notes. Use null if unnecessary."
            ),
            "priority": [
                "type": "string",
                "description": "The reminder priority.",
                "enum": ReminderDraftPriority.allCases.map(\.rawValue)
            ]
        ],
        "required": [
            "title",
            "dueDateString",
            "dueTimeString",
            "rawDueDatePhrase",
            "notes",
            "priority"
        ]
    ]

    private static let calendarEventObject: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "title": [
                "type": "string",
                "description": "A concise event title grounded in the note text, naming what the event actually is."
            ],
            "startDateString": nullableString(
                description: "The event date in YYYY-MM-DD format. Use null when no date can be determined."
            ),
            "startTimeString": nullableString(
                description: "The start time in HH:mm 24-hour format, such as 19:00. Use null for an all-day event or when no time is mentioned."
            ),
            "endTimeString": nullableString(
                description: "The end time in HH:mm 24-hour format. Use null when the note does not say how long the event runs."
            ),
            "isAllDay": [
                "type": "boolean",
                "description": "True when the event has no specific time and occupies the whole day."
            ],
            "location": nullableString(
                description: "Where the event takes place, when the note says. Use null otherwise."
            ),
            "rawDatePhrase": nullableString(
                description: "The original scheduling phrase from the note, such as 'this Friday at 7'. Preserve it whenever one exists."
            ),
            "notes": nullableString(
                description: "Optional supporting context for the event. Use null if unnecessary."
            )
        ],
        "required": [
            "title",
            "startDateString",
            "startTimeString",
            "endTimeString",
            "isAllDay",
            "location",
            "rawDatePhrase",
            "notes"
        ]
    ]

    private static func nullableString(description: String) -> [String: Any] {
        [
            "type": ["string", "null"],
            "description": description
        ]
    }
}
