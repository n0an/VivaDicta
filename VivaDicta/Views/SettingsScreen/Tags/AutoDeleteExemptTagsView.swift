//
//  AutoDeleteExemptTagsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.30
//

import SwiftUI
import SwiftData

/// Lets the user pick which tags shield a note from the automatic cleanup sweeps.
///
/// Writes straight to ``TranscriptionTag/isExcludedFromAutoDelete``, so the same choice
/// shows up in the tag editor and syncs to the Mac app through CloudKit.
struct AutoDeleteExemptTagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionTag.sortOrder) private var tags: [TranscriptionTag]

    var body: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag",
                    description: Text("Create a tag first, then mark it here to keep its notes from being auto-deleted.")
                )
            } else {
                Section {
                    ForEach(tags) { tag in
                        Toggle(isOn: binding(for: tag)) {
                            HStack(spacing: 12) {
                                Image(systemName: tag.icon)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: tag.colorHex) ?? .blue)
                                    .clipShape(.rect(cornerRadius: 6))

                                Text(tag.name)
                            }
                        }
                    }
                } footer: {
                    Text("Notes carrying any of the selected tags are skipped by automatic note and audio cleanup, however old they get.")
                }
            }
        }
        .navigationTitle("Never Auto-delete")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for tag: TranscriptionTag) -> Binding<Bool> {
        Binding(
            get: { tag.isExcludedFromAutoDelete },
            set: { newValue in
                tag.isExcludedFromAutoDelete = newValue
                try? modelContext.save()
                HapticManager.selectionChanged()
            }
        )
    }
}

/// Settings row that opens ``AutoDeleteExemptTagsView`` and summarizes the current picks.
struct AutoDeleteExemptTagsLink: View {
    @Query(sort: \TranscriptionTag.sortOrder) private var tags: [TranscriptionTag]

    private var protectedNames: [String] {
        tags.filter(\.isExcludedFromAutoDelete).map(\.name)
    }

    var body: some View {
        NavigationLink(value: SettingsDestination.autoDeleteExemptTags) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Never Auto-delete")
                    .font(.body)
                Text(protectedNames.isEmpty
                     ? "Mark a tag to keep its notes forever"
                     : protectedNames.formatted(.list(type: .and)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
