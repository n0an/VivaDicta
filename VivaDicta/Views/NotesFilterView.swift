//
//  NotesFilterView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import SwiftUI

struct NotesFilterView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceTags: [String]
    let userTags: [TranscriptionTag]
    let appliedFilter: SavedNotesFilter
    let onApply: (SavedNotesFilter) -> Void

    @State private var draftSourceTags: Set<String>
    @State private var draftUserTagIds: Set<UUID>

    init(
        sourceTags: [String],
        userTags: [TranscriptionTag],
        appliedFilter: SavedNotesFilter,
        onApply: @escaping (SavedNotesFilter) -> Void
    ) {
        self.sourceTags = sourceTags
        self.userTags = userTags
        self.appliedFilter = appliedFilter
        self.onApply = onApply

        let sanitizedFilter = SavedNotesFilterStorage.sanitize(
            appliedFilter,
            availableSourceTags: sourceTags,
            availableUserTagIds: Set(userTags.map(\.id))
        )
        _draftSourceTags = State(initialValue: sanitizedFilter.sourceTags)
        _draftUserTagIds = State(initialValue: sanitizedFilter.userTagIds)
    }

    private var draftFilter: SavedNotesFilter {
        SavedNotesFilter(sourceTags: draftSourceTags, userTagIds: draftUserTagIds)
    }

    private var hasChanges: Bool {
        draftFilter != appliedFilter
    }

    private var hasAvailableFilters: Bool {
        !sourceTags.isEmpty || !userTags.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if !hasAvailableFilters {
                    ContentUnavailableView(
                        "No Filters Yet",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Create tags or add more notes to start filtering.")
                    )
                } else {
                    if !sourceTags.isEmpty {
                        Section("Sources") {
                            ForEach(sourceTags, id: \.self) { tag in
                                selectionRow(
                                    title: SourceTag.displayName(for: tag),
                                    icon: SourceTag.icon(for: tag),
                                    tint: SourceTag.color(for: tag),
                                    isSelected: draftSourceTags.contains(tag)
                                ) {
                                    toggleSourceTag(tag)
                                }
                            }
                        }
                    }

                    if !userTags.isEmpty {
                        Section("Tags") {
                            ForEach(userTags) { tag in
                                selectionRow(
                                    title: tag.name,
                                    icon: tag.icon,
                                    tint: Color(hex: tag.colorHex) ?? .blue,
                                    isSelected: draftUserTagIds.contains(tag.id)
                                ) {
                                    toggleUserTag(tag.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notes Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        if hasAvailableFilters {
            VStack(spacing: 12) {
                Button("Apply Filter", systemImage: "checkmark.circle.fill") {
                    onApply(draftFilter)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .prominentButton(color: .accentColor)
                .disabled(!hasChanges)

                if appliedFilter.isActive {
                    Button("Disable Filter", systemImage: "line.3.horizontal.decrease.circle") {
                        onApply(SavedNotesFilter())
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.bar)
        }
    }

    private func toggleSourceTag(_ tag: String) {
        if draftSourceTags.contains(tag) {
            draftSourceTags.remove(tag)
        } else {
            draftSourceTags.insert(tag)
        }
    }

    private func toggleUserTag(_ tagId: UUID) {
        if draftUserTagIds.contains(tagId) {
            draftUserTagIds.remove(tagId)
        } else {
            draftUserTagIds.insert(tagId)
        }
    }

    private func selectionRow(
        title: String,
        icon: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint)
                    .clipShape(.rect(cornerRadius: 8))

                Text(title)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotesFilterView(
        sourceTags: [SourceTag.app, SourceTag.keyboard],
        userTags: [
            TranscriptionTag(name: "Work", colorHex: "#007AFF", icon: "briefcase.fill"),
            TranscriptionTag(name: "Ideas", colorHex: "#FF9500", icon: "lightbulb.fill")
        ],
        appliedFilter: SavedNotesFilter(
            sourceTags: [SourceTag.app],
            userTagIds: []
        )
    ) { _ in }
}
