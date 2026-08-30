//
//  ReminderSuggestionsFloatingControl.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import SwiftUI
import DesignSystem

struct ReminderSuggestionsFloatingControl: View {
    let pendingReminderDraftCount: Int
    /// Set when calendar events share the badge, so the label stops promising
    /// reminders only.
    var includesCalendarEvents: Bool = false
    let onReviewReminderSuggestions: () -> Void

    private var labelText: String {
        if includesCalendarEvents {
            return pendingReminderDraftCount == 1
                ? "Review Suggestion"
                : "Review Suggestions (\(pendingReminderDraftCount))"
        }
        return pendingReminderDraftCount == 1
            ? "Review Reminder"
            : "Review Reminders (\(pendingReminderDraftCount))"
    }

    var body: some View {
        Button(action: onReviewReminderSuggestions) {
            labelContent
        }
        .buttonStyle(.plain)
    }

    private var labelContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .imageScale(.medium)
                .foregroundStyle(.blue)

            Text(labelText)
                .foregroundStyle(.primary)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay {
            Capsule()
                .strokeBorder(
                    .blue.opacity(0.18),
                    lineWidth: 1
                )
        }
        .glassCapsule(
            tint: .blue.opacity(0.18),
            fallback: .ultraThinMaterial
        )
        
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
