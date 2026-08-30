//
//  ExtractedCalendarEventDraft.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.30
//

import Foundation
import SwiftData

@Model
final class ExtractedCalendarEventDraft {
    var id: UUID = UUID()
    var title: String = ""
    var startDateString: String?
    var endDateString: String?
    var isAllDay: Bool = false
    var location: String?
    var rawDatePhrase: String?
    var notes: String?
    var statusRawValue: String = ExtractedReminderDraftStatus.pending.rawValue
    var eventIdentifier: String?
    var extractionProviderName: String?
    var extractionModelName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(inverse: \Transcription.extractedCalendarEventDrafts)
    var transcription: Transcription?

    init(
        title: String = "",
        startDateString: String? = nil,
        endDateString: String? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        rawDatePhrase: String? = nil,
        notes: String? = nil,
        status: ExtractedReminderDraftStatus = .pending,
        eventIdentifier: String? = nil,
        extractionProviderName: String? = nil,
        extractionModelName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.startDateString = startDateString
        self.endDateString = endDateString
        self.isAllDay = isAllDay
        self.location = location
        self.rawDatePhrase = rawDatePhrase
        self.notes = notes
        self.statusRawValue = status.rawValue
        self.eventIdentifier = eventIdentifier
        self.extractionProviderName = extractionProviderName
        self.extractionModelName = extractionModelName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: ExtractedReminderDraftStatus {
        get { ExtractedReminderDraftStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    var calendarEventDraft: CalendarEventDraft {
        CalendarEventDraft(
            title: title,
            startDateString: startDateString,
            endDateString: endDateString,
            isAllDay: isAllDay,
            location: location,
            rawDatePhrase: rawDatePhrase,
            notes: notes
        )
    }

    func update(
        from draft: CalendarEventDraft,
        providerName: String?,
        modelName: String?,
        status: ExtractedReminderDraftStatus = .pending
    ) {
        title = draft.title
        startDateString = draft.startDateString
        endDateString = draft.endDateString
        isAllDay = draft.isAllDay
        location = draft.location
        rawDatePhrase = draft.rawDatePhrase
        notes = draft.notes
        self.status = status
        extractionProviderName = providerName
        extractionModelName = modelName
        updatedAt = .now
    }

    func markImported(eventIdentifier: String?) {
        status = .imported
        self.eventIdentifier = eventIdentifier
        updatedAt = .now
    }

    func markDismissed() {
        status = .dismissed
        updatedAt = .now
    }
}

extension Transcription {
    var sortedExtractedCalendarEventDrafts: [ExtractedCalendarEventDraft] {
        (extractedCalendarEventDrafts ?? []).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var activeExtractedCalendarEventDrafts: [ExtractedCalendarEventDraft] {
        sortedExtractedCalendarEventDrafts.filter { $0.status != .dismissed }
    }

    var pendingExtractedCalendarEventDrafts: [ExtractedCalendarEventDraft] {
        activeExtractedCalendarEventDrafts.filter { $0.status == .pending }
    }

    var pendingExtractedCalendarEventDraftCount: Int {
        pendingExtractedCalendarEventDrafts.count
    }

    /// Reminders plus calendar events still awaiting review, for the one badge
    /// that covers both.
    var pendingExtractedSuggestionCount: Int {
        pendingExtractedReminderDraftCount + pendingExtractedCalendarEventDraftCount
    }
}
