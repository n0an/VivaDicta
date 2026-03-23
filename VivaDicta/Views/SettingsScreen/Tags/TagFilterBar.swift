//
//  TagFilterBar.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import SwiftUI

/// Horizontal scrollable filter bar with source tags and user tags.
struct TagFilterBar: View {
    let sourceTags: [String]
    let userTags: [TranscriptionTag]
    @Binding var selectedSourceTags: Set<String>
    @Binding var selectedUserTagIds: Set<UUID>

    private var hasActiveFilter: Bool {
        !selectedSourceTags.isEmpty || !selectedUserTagIds.isEmpty
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                // "All" chip
                chipButton(
                    label: "All",
                    icon: nil,
                    isSelected: !hasActiveFilter
                ) {
                    selectedSourceTags.removeAll()
                    selectedUserTagIds.removeAll()
                }

                // Source tag chips
                ForEach(sourceTags, id: \.self) { tag in
                    chipButton(
                        label: SourceTag.displayName(for: tag),
                        icon: SourceTag.icon(for: tag),
                        isSelected: selectedSourceTags.contains(tag),
                        color: SourceTag.color(for: tag)
                    ) {
                        if selectedSourceTags.contains(tag) {
                            selectedSourceTags.remove(tag)
                        } else {
                            selectedSourceTags.insert(tag)
                        }
                    }
                }

                if !sourceTags.isEmpty && !userTags.isEmpty {
                    Divider()
                        .frame(height: 20)
                }

                // User tag chips
                ForEach(userTags) { tag in
                    chipButton(
                        label: tag.name,
                        icon: tag.icon,
                        isSelected: selectedUserTagIds.contains(tag.id),
                        color: Color(hex: tag.colorHex) ?? .blue
                    ) {
                        if selectedUserTagIds.contains(tag.id) {
                            selectedUserTagIds.remove(tag.id)
                        } else {
                            selectedUserTagIds.insert(tag.id)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    private func chipButton(label: String, icon: String?, isSelected: Bool, color: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
