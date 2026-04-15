//
//  ReminderSuggestionsFloatingControl.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import SwiftUI

struct ReminderSuggestionsFloatingControl: View {
    let pendingReminderDraftCount: Int
    let onReviewReminderSuggestions: () -> Void

    private var labelText: String {
        pendingReminderDraftCount == 1
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
            Image(systemName: "tray.full")
                .imageScale(.medium)
                .foregroundStyle(.blue)

            Text(labelText)
                .foregroundStyle(.primary)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCapsule(
            tint: .blue.opacity(0.18),
            fallback: .ultraThinMaterial
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    .blue.opacity(0.18),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
