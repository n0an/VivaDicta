//
//  CalendarEventDraft.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.30
//

import Foundation

struct CalendarEventDraft: Codable, Sendable {
    var title: String

    /// Start as `YYYY-MM-DD` for an all-day event, or `YYYY-MM-DDTHH:mm:ss`.
    var startDateString: String?

    /// End, same shape as `startDateString`. Missing means "default duration".
    var endDateString: String?

    var isAllDay: Bool

    var location: String?

    /// The original scheduling wording from the note, kept when the timing could
    /// not be resolved to a real date.
    var rawDatePhrase: String?

    var notes: String?

    nonisolated init(
        title: String,
        startDateString: String? = nil,
        endDateString: String? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        rawDatePhrase: String? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.startDateString = startDateString
        self.endDateString = endDateString
        self.isAllDay = isAllDay
        self.location = location
        self.rawDatePhrase = rawDatePhrase
        self.notes = notes
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
@Generable(description: "A calendar event extracted from a transcription note for user review before adding to Apple Calendar.")
struct CalendarEventDraftSchema: Sendable {
    @Guide(description: "A concise event title grounded in the note text, naming what the event actually is.")
    var title: String

    @Guide(description: "The event date in YYYY-MM-DD format. Leave it null when no date can be determined.")
    var startDateString: String?

    @Guide(description: "The start time in HH:mm 24-hour format, such as 19:00. Leave it null for an all-day event or when no time is mentioned.")
    var startTimeString: String?

    @Guide(description: "The end time in HH:mm 24-hour format. Leave it null when the note does not say how long the event runs.")
    var endTimeString: String?

    @Guide(description: "True when the event has no specific time and occupies the whole day.")
    var isAllDay: Bool

    @Guide(description: "Where the event takes place, when the note says. Leave it null otherwise.")
    var location: String?

    @Guide(description: "The original scheduling phrase from the note, such as 'this Friday at 7'. Preserve it whenever one exists.")
    var rawDatePhrase: String?

    @Guide(description: "Optional supporting context for the event. Leave it null if unnecessary.")
    var notes: String?

    var calendarEventDraft: CalendarEventDraft {
        CalendarEventDraft(
            title: title,
            startDateString: CalendarEventDraftFields.combined(
                date: startDateString,
                time: isAllDay ? nil : startTimeString
            ),
            endDateString: CalendarEventDraftFields.combined(
                date: startDateString,
                time: isAllDay ? nil : endTimeString
            ),
            isAllDay: isAllDay,
            location: CalendarEventDraftFields.sanitized(location),
            rawDatePhrase: CalendarEventDraftFields.sanitized(rawDatePhrase),
            notes: CalendarEventDraftFields.sanitized(notes)
        )
    }
}
#endif

/// Shared field handling for the two schema shapes (`@Generable` and the JSON
/// payload) that both split an event's timing into a date plus a time.
enum CalendarEventDraftFields {
    nonisolated static func combined(date: String?, time: String?) -> String? {
        guard let trimmedDate = sanitized(date), !trimmedDate.isEmpty else {
            return nil
        }
        guard let trimmedTime = sanitized(time), !trimmedTime.isEmpty else {
            return trimmedDate
        }
        return "\(trimmedDate)T\(trimmedTime):00"
    }

    nonisolated static func sanitized(_ value: String?) -> String? {
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
