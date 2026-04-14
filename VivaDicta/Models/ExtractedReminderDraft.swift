//
//  ExtractedReminderDraft.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation
import SwiftData

enum ExtractedReminderDraftStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case imported
    case dismissed
}

@Model
final class ExtractedReminderDraft {
    var id: UUID = UUID()
    var title: String = ""
    var optionalDueDateString: String?
    var rawDueDatePhrase: String?
    var notes: String?
    var priorityRawValue: String = ReminderDraftPriority.none.rawValue
    var statusRawValue: String = ExtractedReminderDraftStatus.pending.rawValue
    var reminderIdentifier: String?
    var extractionProviderName: String?
    var extractionModelName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(inverse: \Transcription.extractedReminderDrafts)
    var transcription: Transcription?

    init(
        title: String = "",
        optionalDueDateString: String? = nil,
        rawDueDatePhrase: String? = nil,
        notes: String? = nil,
        priority: ReminderDraftPriority = .none,
        status: ExtractedReminderDraftStatus = .pending,
        reminderIdentifier: String? = nil,
        extractionProviderName: String? = nil,
        extractionModelName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.optionalDueDateString = optionalDueDateString
        self.rawDueDatePhrase = rawDueDatePhrase
        self.notes = notes
        self.priorityRawValue = priority.rawValue
        self.statusRawValue = status.rawValue
        self.reminderIdentifier = reminderIdentifier
        self.extractionProviderName = extractionProviderName
        self.extractionModelName = extractionModelName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var priority: ReminderDraftPriority {
        get { ReminderDraftPriority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }

    var status: ExtractedReminderDraftStatus {
        get { ExtractedReminderDraftStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    var reminderDraft: ReminderDraft {
        ReminderDraft(
            title: title,
            optionalDueDateString: optionalDueDateString,
            rawDueDatePhrase: rawDueDatePhrase,
            notes: notes,
            priority: priority
        )
    }

    func update(
        from draft: ReminderDraft,
        providerName: String?,
        modelName: String?,
        status: ExtractedReminderDraftStatus = .pending
    ) {
        title = draft.title
        optionalDueDateString = draft.optionalDueDateString
        rawDueDatePhrase = draft.rawDueDatePhrase
        notes = draft.notes
        priority = draft.priority
        self.status = status
        extractionProviderName = providerName
        extractionModelName = modelName
        updatedAt = .now
    }

    func markImported(reminderIdentifier: String?) {
        status = .imported
        self.reminderIdentifier = reminderIdentifier
        updatedAt = .now
    }

    func markDismissed() {
        status = .dismissed
        updatedAt = .now
    }
}

extension Transcription {
    var sortedExtractedReminderDrafts: [ExtractedReminderDraft] {
        (extractedReminderDrafts ?? []).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var pendingExtractedReminderDrafts: [ExtractedReminderDraft] {
        sortedExtractedReminderDrafts.filter { $0.status == .pending }
    }

    var pendingExtractedReminderDraftCount: Int {
        pendingExtractedReminderDrafts.count
    }
}
