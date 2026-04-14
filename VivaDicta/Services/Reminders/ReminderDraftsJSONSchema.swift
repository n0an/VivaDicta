//
//  ReminderDraftsJSONSchema.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

enum ReminderDraftsJSONSchema {
    static let object: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "reminders": [
                "type": "array",
                "description": "Reminder drafts that should be shown to the user for review. Return an empty array when the note does not contain reminder-worthy actions.",
                "items": reminderDraftObject
            ],
            "summary": nullableString(
                description: "Optional short summary of the extraction result, such as 'Found 2 reminder suggestions'."
            )
        ],
        "required": [
            "reminders",
            "summary"
        ]
    ]

    private static let reminderDraftObject: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "title": [
                "type": "string",
                "description": "A concise reminder title grounded in the note text. Keep it short and actionable, and preserve the actual action, person, or object mentioned in the note."
            ],
            "optionalDueDateString": nullableString(
                description: "An absolute due date when confidently known. If the note contains a resolvable weekday or relative due phrase such as 'Saturday at 9 am', 'tomorrow noon', or 'next Thursday at 14:00', calculate the exact date using the current date and time zone. Prefer ISO 8601 date-time like 2026-04-19T09:00:00+01:00. Also accept 2026-04-19T09:00:00 when no time zone suffix is present. If only the date is known, 2026-04-19 is acceptable. Use null only when the timing is ambiguous or not mentioned."
            ),
            "rawDueDatePhrase": nullableString(
                description: "The original due date phrase from the note, such as 'tomorrow noon' or 'end of week'. Preserve this whenever a due phrase exists, even if optionalDueDateString is also set. Use null when no due phrase exists."
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
            "optionalDueDateString",
            "rawDueDatePhrase",
            "notes",
            "priority"
        ]
    ]

    private static func nullableString(description: String) -> [String: Any] {
        [
            "type": ["string", "null"],
            "description": description
        ]
    }
}
