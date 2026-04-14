//
//  TranscriptionTagChipsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import SwiftUI
import SwiftData

/// Horizontal scrollable row of tag chips for a transcription.
struct TranscriptionTagChipsView: View {
    let transcription: Transcription
    let reviewReminderCount: Int
    let pendingReminderCount: Int
    var onReviewReminderSuggestions: (() -> Void)?
    @Query(sort: \TranscriptionTag.sortOrder) private var allTags: [TranscriptionTag]
    @Binding var showTagPicker: Bool

    private var assignedTags: [TranscriptionTag] {
        let assignedIds = Set((transcription.tagAssignments ?? []).map(\.tagId))
        return allTags.filter { assignedIds.contains($0.id) }
    }

    private var reminderTitle: String {
        let count = pendingReminderCount > 0 ? pendingReminderCount : reviewReminderCount
        return count == 1 ? "1 Task" : "\(count) Tasks"
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                // Source tag badge
                if let sourceTag = transcription.sourceTag {
                    Label(SourceTag.displayName(for: sourceTag), systemImage: SourceTag.icon(for: sourceTag))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SourceTag.color(for: sourceTag).opacity(0.15))
                        .foregroundStyle(SourceTag.color(for: sourceTag))
                        .clipShape(.capsule)
                }

                // User tag chips
                ForEach(assignedTags) { tag in
                    Label(tag.name, systemImage: tag.icon)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((Color(hex: tag.colorHex) ?? .blue).opacity(0.15))
                        .foregroundStyle(Color(hex: tag.colorHex) ?? .blue)
                        .clipShape(.capsule)
                }

                if reviewReminderCount > 0,
                   let onReviewReminderSuggestions {
                    Button(action: onReviewReminderSuggestions) {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                            Text(reminderTitle)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review \(reminderTitle.lowercased())")
                }

                // Add tag button
                Button {
                    showTagPicker = true
                } label: {
                    Label("Tag", systemImage: "plus")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .foregroundStyle(.secondary)
                        .clipShape(.capsule)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
