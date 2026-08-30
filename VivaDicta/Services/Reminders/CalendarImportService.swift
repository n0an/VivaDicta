//
//  CalendarImportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.30
//

import EventKit
import Foundation
import os

enum CalendarImportError: LocalizedError {
    case accessDenied
    case writeOnlyAccessInsufficient
    case unknownAuthorizationStatus
    case defaultCalendarUnavailable
    case unresolvableStartDate

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Enable it in Settings to add events."
        case .writeOnlyAccessInsufficient:
            return "Full Calendar access is required to add events."
        case .unknownAuthorizationStatus:
            return "Calendar permission status is unknown."
        case .defaultCalendarUnavailable:
            return "No default calendar is available on this device."
        case .unresolvableStartDate:
            return "This event has no date that could be resolved, so it cannot be added to a calendar."
        }
    }

    var shouldOfferSettingsShortcut: Bool {
        switch self {
        case .accessDenied, .writeOnlyAccessInsufficient:
            true
        case .unknownAuthorizationStatus, .defaultCalendarUnavailable, .unresolvableStartDate:
            false
        }
    }
}

@MainActor
final class CalendarImportService {
    /// What a timed event gets when the note never said how long it runs. An
    /// hour is the common default across calendar apps.
    private static let defaultDuration: TimeInterval = 60 * 60

    private let logger = Logger(category: .calendarImport)
    private let eventStore = EKEventStore()

    /// Whether the draft resolved to a real date. A draft that only carries a
    /// raw phrase is shown for review but cannot be added.
    static func canImport(_ draft: CalendarEventDraft) -> Bool {
        ReminderDueDateParser.parse(draft.startDateString) != nil
    }

    func importDraft(_ draft: CalendarEventDraft) async throws -> String? {
        try await ensureAccess()

        guard let startDate = ReminderDueDateParser.parse(draft.startDateString) else {
            throw CalendarImportError.unresolvableStartDate
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = draft.title
        event.notes = draft.notes
        event.location = draft.location
        event.calendar = try defaultCalendar()
        event.isAllDay = draft.isAllDay
        event.startDate = startDate

        if draft.isAllDay {
            event.endDate = startDate
        } else if let endDate = ReminderDueDateParser.parse(draft.endDateString), endDate > startDate {
            event.endDate = endDate
        } else {
            event.endDate = startDate.addingTimeInterval(Self.defaultDuration)
        }

        try eventStore.save(event, span: .thisEvent, commit: true)
        let identifier = event.calendarItemExternalIdentifier.isEmpty
            ? event.eventIdentifier
            : event.calendarItemExternalIdentifier
        logger.logNotice("Calendar import - Created event title='\(draft.title)'")
        return identifier
    }

    private func ensureAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted else {
                throw CalendarImportError.accessDenied
            }
        case .restricted, .denied:
            throw CalendarImportError.accessDenied
        case .writeOnly:
            // Write-only can create events but not read back the calendar list,
            // which is how we pick a destination.
            throw CalendarImportError.writeOnlyAccessInsufficient
        case .authorized, .fullAccess:
            break
        @unknown default:
            throw CalendarImportError.unknownAuthorizationStatus
        }
    }

    private func defaultCalendar() throws -> EKCalendar {
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw CalendarImportError.defaultCalendarUnavailable
        }
        return calendar
    }
}
