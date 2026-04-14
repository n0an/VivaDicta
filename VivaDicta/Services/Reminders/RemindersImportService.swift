//
//  RemindersImportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import EventKit
import Foundation
import os

enum RemindersImportError: LocalizedError {
    case accessDenied
    case readAccessRequired
    case unknownAuthorizationStatus
    case defaultReminderListUnavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access was denied. Enable it in Settings to import reminder suggestions."
        case .readAccessRequired:
            return "Full Reminders access is required to create reminders."
        case .unknownAuthorizationStatus:
            return "Reminders permission status is unknown."
        case .defaultReminderListUnavailable:
            return "No default Reminders list is available on this device."
        }
    }

    var shouldOfferSettingsShortcut: Bool {
        switch self {
        case .accessDenied, .readAccessRequired:
            true
        case .unknownAuthorizationStatus, .defaultReminderListUnavailable:
            false
        }
    }
}

@MainActor
final class RemindersImportService {
    private let logger = Logger(category: .remindersImport)
    private let eventStore = EKEventStore()

    func importDraft(_ draft: ReminderDraft) async throws -> String? {
        try await ensureAccess()

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = draft.title
        reminder.notes = draft.notes
        reminder.priority = draft.priority.eventKitPriority
        reminder.calendar = try defaultReminderCalendar()

        if let dueDateComponents = ReminderDueDateParser.dueDateComponents(from: draft.optionalDueDateString) {
            reminder.dueDateComponents = dueDateComponents
        }

        try eventStore.save(reminder, commit: true)
        let identifier = reminder.calendarItemExternalIdentifier.isEmpty
            ? reminder.calendarItemIdentifier
            : reminder.calendarItemExternalIdentifier
        logger.logNotice("Reminder import - Created reminder title='\(draft.title)'")
        return identifier
    }

    func importDrafts(_ drafts: [ReminderDraft]) async throws -> [String?] {
        var identifiers: [String?] = []
        identifiers.reserveCapacity(drafts.count)

        for draft in drafts {
            identifiers.append(try await importDraft(draft))
        }

        return identifiers
    }

    private func ensureAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToReminders()
            guard granted else {
                throw RemindersImportError.accessDenied
            }
        case .restricted, .denied:
            throw RemindersImportError.accessDenied
        case .writeOnly:
            throw RemindersImportError.readAccessRequired
        case .authorized, .fullAccess:
            break
        @unknown default:
            throw RemindersImportError.unknownAuthorizationStatus
        }
    }

    private func defaultReminderCalendar() throws -> EKCalendar {
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw RemindersImportError.defaultReminderListUnavailable
        }
        return calendar
    }
}
