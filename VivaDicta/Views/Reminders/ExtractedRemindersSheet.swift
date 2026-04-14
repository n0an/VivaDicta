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
    @Query(sort: \ExtractedReminderDraft.createdAt) private var allReminderDrafts: [ExtractedReminderDraft]

    @State private var importingDraftIDs = Set<UUID>()
    @State private var isImportingAll = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var shouldOfferSettingsShortcut = false

    private var pendingDrafts: [ExtractedReminderDraft] {
        allReminderDrafts.filter {
            $0.transcription?.id == transcription.id && $0.status == .pending
        }
    }

    private var isBusy: Bool {
        isImportingAll || !importingDraftIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if pendingDrafts.isEmpty {
                    ContentUnavailableView(
                        "No Reminder Suggestions",
                        systemImage: "checklist",
                        description: Text("Extracted reminder drafts will appear here for review before importing to Apple Reminders.")
                    )
                } else {
                    List {
                        ForEach(pendingDrafts, id: \.id) { draft in
                            ExtractedReminderDraftRow(
                                draft: draft,
                                isImporting: importingDraftIDs.contains(draft.id) || isImportingAll
                            )
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Add to Reminders", systemImage: "checkmark.circle.fill") {
                                    Task {
                                        await importDraft(draft)
                                    }
                                }
                                .tint(.green)
                                .disabled(isBusy)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Dismiss", systemImage: "trash") {
                                    dismissDraft(draft)
                                }
                                .tint(.red)
                                .disabled(isBusy)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Reminder Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if pendingDrafts.count > 1 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add All") {
                            Task {
                                await importAllDrafts()
                            }
                        }
                        .disabled(isBusy)
                    }
                }
            }
        }
        .alert("Reminder Import Failed", isPresented: $showErrorAlert) {
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

    private func importAllDrafts() async {
        let draftsToImport = pendingDrafts
        guard !draftsToImport.isEmpty else { return }

        isImportingAll = true
        defer {
            isImportingAll = false
        }

        do {
            let identifiers = try await RemindersImportService().importDrafts(draftsToImport.map(\.reminderDraft))
            for (draft, identifier) in zip(draftsToImport, identifiers) {
                draft.markImported(reminderIdentifier: identifier)
            }
            try modelContext.save()
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: any Error) {
        errorMessage = error.localizedDescription
        shouldOfferSettingsShortcut = (error as? RemindersImportError)?.shouldOfferSettingsShortcut ?? false
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

                    if draft.priority != .none {
                        Text(priorityLabel(for: draft.priority))
                            .font(.caption)
                            .foregroundStyle(priorityColor(for: draft.priority))
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

    private func priorityLabel(for priority: ReminderDraftPriority) -> String {
        switch priority {
        case .none:
            "No Priority"
        case .low:
            "Low Priority"
        case .medium:
            "Medium Priority"
        case .high:
            "High Priority"
        }
    }

    private func priorityColor(for priority: ReminderDraftPriority) -> Color {
        switch priority {
        case .none:
            .secondary
        case .low:
            .blue
        case .medium:
            .orange
        case .high:
            .red
        }
    }
}
