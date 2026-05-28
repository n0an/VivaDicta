//
//  RecordingTagChipsRow.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.28
//

import SwiftUI
import SwiftData

/// Horizontal row of selectable tag chips shown inline in the recording sheet.
///
/// Toggles membership in `selectedTagIds` (buffered on ``RecordViewModel/pendingTagIds``)
/// without touching SwiftData. The chosen tags are applied to the new `Transcription`
/// when the recording is saved. Picks from existing tags only - tag creation lives in Settings.
struct RecordingTagChipsRow: View {
    @Binding var selectedTagIds: Set<UUID>
    @Query(sort: \TranscriptionTag.sortOrder) private var allTags: [TranscriptionTag]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(allTags) { tag in
                    let isSelected = selectedTagIds.contains(tag.id)
                    let tagColor = Color(hex: tag.colorHex) ?? .blue
                    Button {
                        toggle(tag)
                    } label: {
                        Label(tag.name, systemImage: isSelected ? "checkmark" : tag.icon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? tagColor : tagColor.opacity(0.15))
                            .foregroundStyle(isSelected ? .white : tagColor)
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    private func toggle(_ tag: TranscriptionTag) {
        if selectedTagIds.contains(tag.id) {
            selectedTagIds.remove(tag.id)
        } else {
            selectedTagIds.insert(tag.id)
        }
        HapticManager.selectionChanged()
    }
}
