//
//  ReminderExtractionPrompts.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.30
//

import Foundation

/// The system/user prompt pair every reminder extraction backend sends, so the
/// on-device and cloud paths stay worded identically.
enum ReminderExtractionPrompts {
    static func systemMessage(
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool = false
    ) -> String {
        let languageHint = language.map {
            "\nSource note language: \($0). Write title, notes, and rawDueDatePhrase in this language."
        } ?? ""
        let eventsClause = includeEvents
            ? "\nAlso extract calendar events - things that happen at a set time and that the user attends. Every item is either a reminder or an event, never both."
            : ""
        return """
        You extract reminder suggestions from transcription notes.\(eventsClause)
        Return structured drafts for user review before importing to Apple Reminders or Apple Calendar.
        Use only the current note as the source of truth.
        Do not invent tasks or deadlines.
        Always preserve the source-note language in the human-readable fields (title, notes, rawDueDatePhrase). Do not translate to another language. Field names and enum values stay in English.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone identifier: \(timeZone.identifier)\(languageHint)
        """
    }

    static func userMessage(
        noteText: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool = false
    ) -> String {
        let languageHint = language.map {
            "Source note language: \($0). Write title, notes, and rawDueDatePhrase in this language.\n\n"
        } ?? ""
        return """
        Extract \(includeEvents ? "reminder and calendar-event suggestions" : "reminder suggestions") from this note.

        Current absolute date and time: \(now.ISO8601Format())
        Current time zone: \(timeZone.identifier)

        \(languageHint)Rules:
        - Extract only genuine reminder-worthy actions, commitments, or follow-ups that belong in Apple Reminders.
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
        \(includeEvents ? eventRules : "")
        Examples of good extraction (English shown for format only - your output language must match the Note):
        \(fewShotExamples(now: now, timeZone: timeZone, includeEvents: includeEvents))

        Note:
        \(noteText)
        """
    }

    /// The user message plus an explicit JSON contract, for backends that cannot
    /// enforce a schema and answer with plain text (OAuth clients, CLIs).
    static func textTransportUserMessage(
        noteText: String,
        now: Date,
        timeZone: TimeZone,
        language: String?,
        includeEvents: Bool = false
    ) -> String {
        let eventsShape = includeEvents ? """
          "events": [
            {
              "title": "string",
              "startDateString": "YYYY-MM-DD or null",
              "startTimeString": "HH:mm or null",
              "endTimeString": "HH:mm or null",
              "isAllDay": true or false,
              "location": "string or null",
              "rawDatePhrase": "string or null",
              "notes": "string or null"
            }
          ],
        """ : ""
        return """
        \(userMessage(noteText: noteText, now: now, timeZone: timeZone, language: language, includeEvents: includeEvents))

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
        \(eventsShape)  "summary": "string or null"
        }
        """
    }

    /// What separates the two buckets. Without this the same sentence lands in
    /// both, which is the failure users notice first.
    private static let eventRules = """

        Reminders vs events:
        - An **event** is something that happens at a set time and that the user attends or that occupies them: a dinner, a meeting, an appointment, a flight, a birthday. It belongs in `events`.
        - A **reminder** is a task the user has to do: call someone, buy something, send a file, pay a bill. It belongs in `reminders`.
        - Classify each item as exactly one. Never emit the same thing as both a reminder and an event.
        - "Remind me about the dentist appointment on Saturday at 10" is an event, not a reminder - the appointment is the thing, the reminding is just how it was phrased.
        - "I need to book a dentist appointment" is a reminder - booking is the task, and there is no time to attend yet.
        - Set `isAllDay` true and leave the times null for something with a day but no time, such as a birthday.
        - Set `endTimeString` only when the note says how long the event runs. Leave it null otherwise.
        - Put a place in `location` only when the note names one.
        - If the note contains no events, return an empty events array.
        """

    private static func fewShotExamples(
        now: Date,
        timeZone: TimeZone,
        includeEvents: Bool = false
    ) -> String {
        let saturdayAtTen = nextWeekdayDate(weekday: 7, hour: 10, minute: 0, now: now, timeZone: timeZone)
        let sundayAtTen = nextWeekdayDate(weekday: 1, hour: 10, minute: 0, now: now, timeZone: timeZone)
        let fridayDateOnly = nextWeekdayDateOnlyString(weekday: 6, now: now, timeZone: timeZone) ?? "2026-04-17"

        if includeEvents {
            return """
            Example 1
            Note: "I have a dinner with my friends this Friday at 7."
            Good response:
            {"reminders":[],"events":[{"title":"Dinner with friends","startDateString":"\(fridayDateOnly)","startTimeString":"19:00","endTimeString":null,"isAllDay":false,"location":null,"rawDatePhrase":"this Friday at 7","notes":null}],"summary":"Found 1 event."}

            Example 2
            Note: "Okay, I need to call my parents on Sunday at 10 a.m."
            Good response:
            {"reminders":[{"title":"Call parents","dueDateString":"\(formattedDateString(from: sundayAtTen, timeZone: timeZone) ?? "2026-04-19")","dueTimeString":"\(formattedTimeString(from: sundayAtTen, timeZone: timeZone) ?? "10:00")","rawDueDatePhrase":"Sunday at 10 a.m.","notes":null,"priority":"high"}],"events":[],"summary":"Found 1 reminder suggestion."}

            Example 3
            Note: "Dentist on Saturday at 10, and I still need to pick up the prescription."
            Good response:
            {"reminders":[{"title":"Pick up prescription","dueDateString":null,"dueTimeString":null,"rawDueDatePhrase":null,"notes":null,"priority":"medium"}],"events":[{"title":"Dentist","startDateString":"\(formattedDateString(from: saturdayAtTen, timeZone: timeZone) ?? "2026-04-18")","startTimeString":"\(formattedTimeString(from: saturdayAtTen, timeZone: timeZone) ?? "10:00")","endTimeString":null,"isAllDay":false,"location":null,"rawDatePhrase":"Saturday at 10","notes":null}],"summary":"Found 1 reminder and 1 event."}

            Example 4
            Note: "I had coffee and answered emails."
            Good response:
            {"reminders":[],"events":[],"summary":"No suggestions found."}
            """
        }

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

    private static func nextWeekdayDate(
        weekday: Int,
        hour: Int,
        minute: Int,
        now: Date,
        timeZone: TimeZone
    ) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = timeZone

        return calendar(timeZone: timeZone).nextDate(
            after: now.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private static func nextWeekdayDateOnlyString(
        weekday: Int,
        now: Date,
        timeZone: TimeZone
    ) -> String? {
        guard let date = nextWeekdayDate(weekday: weekday, hour: 9, minute: 0, now: now, timeZone: timeZone) else {
            return nil
        }
        return formattedDateString(from: date, timeZone: timeZone)
    }

    private static func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func formattedDateString(from date: Date?, timeZone: TimeZone) -> String? {
        guard let date else { return nil }

        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                timeZone: timeZone,
                calendar: calendar(timeZone: timeZone)
            )
        )
    }

    private static func formattedTimeString(from date: Date?, timeZone: TimeZone) -> String? {
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
