//
//  ExtractedRemindersSheet.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ExtractedRemindersSheet: View {
    @Bindable var transcription: Transcription

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var importingDraftIDs = Set<UUID>()
    @State private var isImportingAll = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var errorTitle = "Reminder Import Failed"
    @State private var shouldOfferSettingsShortcut = false

    private var visibleDrafts: [ExtractedReminderDraft] {
        transcription.activeExtractedReminderDrafts
    }

    private var pendingDrafts: [ExtractedReminderDraft] {
        transcription.pendingExtractedReminderDrafts
    }

    private var visibleEvents: [ExtractedCalendarEventDraft] {
        transcription.activeExtractedCalendarEventDrafts
    }

    private var pendingEvents: [ExtractedCalendarEventDraft] {
        transcription.pendingExtractedCalendarEventDrafts
    }

    private var isEmpty: Bool {
        visibleDrafts.isEmpty && visibleEvents.isEmpty
    }

    /// Section headers only earn their space when both kinds are on screen.
    private var showsSectionHeaders: Bool {
        !visibleDrafts.isEmpty && !visibleEvents.isEmpty
    }

    private var pendingTotal: Int {
        pendingDrafts.count + pendingEvents.count
    }

    private var isBusy: Bool {
        isImportingAll || !importingDraftIDs.isEmpty
    }

    private var navigationTitle: String {
        visibleEvents.isEmpty ? "Reminder Suggestions" : "Suggestions"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    ContentUnavailableView(
                        "No Suggestions",
                        systemImage: "checklist",
                        description: Text("Extracted drafts will appear here for review before anything is added to Apple Reminders or Calendar.")
                    )
                } else {
                    List {
                        if !visibleDrafts.isEmpty {
                            Section {
                                ForEach(visibleDrafts, id: \.id) { draft in
                                    reminderRow(draft)
                                }
                            } header: {
                                if showsSectionHeaders {
                                    Text("Reminders")
                                }
                            }
                        }

                        if !visibleEvents.isEmpty {
                            Section {
                                ForEach(visibleEvents, id: \.id) { event in
                                    calendarEventRow(event)
                                }
                            } header: {
                                if showsSectionHeaders {
                                    Text("Calendar Events")
                                }
                            }
                        }

                        Section {
                            Text("Swipe right to add. Swipe left to dismiss.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }

                if pendingTotal > 0 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(pendingTotal > 1 ? "Add All" : "Add") {
                            Task {
                                await importAllDrafts()
                            }
                        }
                        .disabled(isBusy)
                    }
                }
            }
        }
        .alert(errorTitle, isPresented: $showErrorAlert) {
            if shouldOfferSettingsShortcut {
                Button("Settings") {
                    openAppSettings()
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func reminderRow(_ draft: ExtractedReminderDraft) -> some View {
        ExtractedReminderDraftRow(
            draft: draft,
            isImporting: importingDraftIDs.contains(draft.id) || isImportingAll
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if draft.status == .pending {
                Button("Add to Reminders", systemImage: "checkmark.circle.fill") {
                    Task {
                        await importDraft(draft)
                    }
                }
                .tint(.green)
                .disabled(isBusy)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Dismiss", systemImage: "trash") {
                dismissDraft(draft)
            }
            .tint(.red)
            .disabled(isBusy)
        }
    }

    private func calendarEventRow(_ event: ExtractedCalendarEventDraft) -> some View {
        ExtractedCalendarEventRow(
            event: event,
            isImporting: importingDraftIDs.contains(event.id) || isImportingAll
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if event.status == .pending, CalendarImportService.canImport(event.calendarEventDraft) {
                Button("Add to Calendar", systemImage: "calendar.badge.plus") {
                    Task {
                        await importEvent(event)
                    }
                }
                .tint(.green)
                .disabled(isBusy)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Dismiss", systemImage: "trash") {
                dismissEvent(event)
            }
            .tint(.red)
            .disabled(isBusy)
        }
    }

    private func dismissDraft(_ draft: ExtractedReminderDraft) {
        draft.markDismissed()
        do {
            try modelContext.save()
        } catch {
            presentError(error)
        }
    }

    private func importDraft(_ draft: ExtractedReminderDraft) async {
        importingDraftIDs.insert(draft.id)
        defer {
            importingDraftIDs.remove(draft.id)
        }

        do {
            let identifier = try await RemindersImportService().importDraft(draft.reminderDraft)
            draft.markImported(reminderIdentifier: identifier)
            try modelContext.save()
        } catch {
            presentError(error)
        }
    }

    private func dismissEvent(_ event: ExtractedCalendarEventDraft) {
        event.markDismissed()
        do {
            try modelContext.save()
        } catch {
            presentError(error)
        }
    }

    private func importEvent(_ event: ExtractedCalendarEventDraft) async {
        importingDraftIDs.insert(event.id)
        defer {
            importingDraftIDs.remove(event.id)
        }

        do {
            let identifier = try await CalendarImportService().importDraft(event.calendarEventDraft)
            event.markImported(eventIdentifier: identifier)
            try modelContext.save()
        } catch {
            presentError(error)
        }
    }

    private func importAllDrafts() async {
        let draftsToImport = pendingDrafts
        // An event whose timing never resolved has no start date, so EventKit
        // cannot take it - leave it behind for review.
        let eventsToImport = pendingEvents.filter { CalendarImportService.canImport($0.calendarEventDraft) }
        guard !draftsToImport.isEmpty || !eventsToImport.isEmpty else { return }

        isImportingAll = true
        defer {
            isImportingAll = false
        }

        let importService = RemindersImportService()
        let calendarService = CalendarImportService()

        do {
            for draft in draftsToImport {
                let identifier = try await importService.importDraft(draft.reminderDraft)
                draft.markImported(reminderIdentifier: identifier)
                try modelContext.save()
            }
            for event in eventsToImport {
                let identifier = try await calendarService.importDraft(event.calendarEventDraft)
                event.markImported(eventIdentifier: identifier)
                try modelContext.save()
            }
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: any Error) {
        errorMessage = error.localizedDescription

        if let reminderError = error as? RemindersImportError {
            errorTitle = "Reminder Import Failed"
            shouldOfferSettingsShortcut = reminderError.shouldOfferSettingsShortcut
        } else if let calendarError = error as? CalendarImportError {
            errorTitle = "Calendar Import Failed"
            shouldOfferSettingsShortcut = calendarError.shouldOfferSettingsShortcut
        } else {
            errorTitle = "Import Failed"
            shouldOfferSettingsShortcut = false
        }

        showErrorAlert = true
    }

    private func openAppSettings() {
#if canImport(UIKit)
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
#endif
    }
}

private struct ExtractedReminderDraftRow: View {
    let draft: ExtractedReminderDraft
    let isImporting: Bool

    private var dueDateText: String? {
        ReminderDueDateParser.displayText(
            dueDateString: draft.optionalDueDateString,
            rawDueDatePhrase: draft.rawDueDatePhrase
        )
    }

    private var statusText: String? {
        switch draft.status {
        case .pending:
            nil
        case .imported:
            "Added to Reminders"
        case .dismissed:
            "Dismissed"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.title)
                        .font(.body)
                        .bold()

                    if let dueDateText {
                        Label(dueDateText, systemImage: "calendar")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let notes = draft.notes,
                       !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let statusText {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer(minLength: 0)

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ExtractedCalendarEventRow: View {
    let event: ExtractedCalendarEventDraft
    let isImporting: Bool

    /// A draft whose timing never resolved can be reviewed but not added.
    private var canImport: Bool {
        CalendarImportService.canImport(event.calendarEventDraft)
    }

    private var whenText: String? {
        guard let start = ReminderDueDateParser.parse(event.startDateString) else {
            return event.rawDatePhrase
        }

        if event.isAllDay {
            return "\(start.formatted(date: .abbreviated, time: .omitted)) · All day"
        }

        let startText = start.formatted(date: .abbreviated, time: .shortened)
        guard let end = ReminderDueDateParser.parse(event.endDateString), end > start else {
            return startText
        }
        return "\(startText) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private var statusText: String? {
        switch event.status {
        case .pending:
            nil
        case .imported:
            "Added to Calendar"
        case .dismissed:
            "Dismissed"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.body)
                    .bold()

                if let whenText {
                    Label(whenText, systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let location = event.location,
                   !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let notes = event.notes,
                   !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if !canImport {
                    Label("No date could be resolved", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            if isImporting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
