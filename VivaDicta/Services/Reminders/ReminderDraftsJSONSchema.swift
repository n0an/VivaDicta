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

    private static func nullableString(description: String) -> [String: Any] {
        [
            "type": ["string", "null"],
            "description": description
        ]
    }
}
