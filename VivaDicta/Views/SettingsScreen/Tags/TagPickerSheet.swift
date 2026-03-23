//
//  TagPickerSheet.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import SwiftUI
import SwiftData

/// Sheet for assigning/removing tags on a transcription.
struct TagPickerSheet: View {
    let transcription: Transcription
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TranscriptionTag.sortOrder) private var allTags: [TranscriptionTag]

    @State private var showCreateTag = false

    private var assignedTagIds: Set<UUID> {
        Set((transcription.tagAssignments ?? []).map(\.tagId))
    }

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag",
                        description: Text("Create your first tag to start organizing.")
                    )
                } else {
                    ForEach(allTags) { tag in
                        let isAssigned = assignedTagIds.contains(tag.id)
                        Button {
                            toggleTag(tag, isAssigned: isAssigned)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tag.icon)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: tag.colorHex) ?? .blue)
                                    .clipShape(.rect(cornerRadius: 8))

                                Text(tag.name)
                                    .font(.body)

                                Spacer()

                                if isAssigned {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Tag", systemImage: "plus") {
                        showCreateTag = true
                    }
                }
            }
            .sheet(isPresented: $showCreateTag) {
                TagEditorSheet(mode: .create) { name, colorHex, icon in
                    let tag = TranscriptionTag(name: name, colorHex: colorHex, icon: icon, sortOrder: allTags.count)
                    modelContext.insert(tag)
                    try? modelContext.save()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func toggleTag(_ tag: TranscriptionTag, isAssigned: Bool) {
        if isAssigned {
            // Remove assignment
            let tagId = tag.id
            if let assignments = transcription.tagAssignments {
                for assignment in assignments where assignment.tagId == tagId {
                    modelContext.delete(assignment)
                }
            }
        } else {
            // Add assignment
            let assignment = TranscriptionTagAssignment(tagId: tag.id, transcription: transcription)
            modelContext.insert(assignment)
        }
        try? modelContext.save()
        HapticManager.selectionChanged()
    }
}
