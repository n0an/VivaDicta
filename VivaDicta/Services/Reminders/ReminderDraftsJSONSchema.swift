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
                "description": "A concise reminder title, such as 'Call mom' or 'Visit dentist'. Keep it short and actionable."
            ],
            "optionalDueDateString": nullableString(
                description: "An absolute due date in ISO 8601 format with time zone when confidently known, such as 2026-04-15T12:00:00+01:00. Use null when the timing is ambiguous or not mentioned."
            ),
            "rawDueDatePhrase": nullableString(
                description: "The original due date phrase from the note, such as 'tomorrow noon' or 'end of week'. Use null when no due phrase exists."
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
