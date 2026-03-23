//
//  BulkTagPickerSheet.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import SwiftUI
import SwiftData

/// Sheet for assigning/removing tags on multiple transcriptions at once.
struct BulkTagPickerSheet: View {
    let transcriptionIDs: Set<UUID>
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TranscriptionTag.sortOrder) private var allTags: [TranscriptionTag]
    @Query private var allTranscriptions: [Transcription]

    @State private var showCreateTag = false

    private var selectedTranscriptions: [Transcription] {
        allTranscriptions.filter { transcriptionIDs.contains($0.id) }
    }

    /// Returns how many of the selected transcriptions have this tag assigned
    private func assignmentCount(for tag: TranscriptionTag) -> Int {
        let tagId = tag.id
        return selectedTranscriptions.filter { transcription in
            (transcription.tagAssignments ?? []).contains { $0.tagId == tagId }
        }.count
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
                        let count = assignmentCount(for: tag)
                        let allAssigned = count == transcriptionIDs.count
                        let someAssigned = count > 0 && !allAssigned

                        Button {
                            toggleTag(tag, allCurrentlyAssigned: allAssigned)
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

                                if allAssigned {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                } else if someAssigned {
                                    Image(systemName: "minus")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Tag \(transcriptionIDs.count) Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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

    private func toggleTag(_ tag: TranscriptionTag, allCurrentlyAssigned: Bool) {
        let tagId = tag.id

        if allCurrentlyAssigned {
            // Remove from all selected
            for transcription in selectedTranscriptions {
                if let assignments = transcription.tagAssignments {
                    for assignment in assignments where assignment.tagId == tagId {
                        modelContext.delete(assignment)
                    }
                }
            }
        } else {
            // Add to all selected that don't have it
            for transcription in selectedTranscriptions {
                let alreadyAssigned = (transcription.tagAssignments ?? []).contains { $0.tagId == tagId }
                if !alreadyAssigned {
                    let assignment = TranscriptionTagAssignment(tagId: tagId, transcription: transcription)
                    modelContext.insert(assignment)
                }
            }
        }
        try? modelContext.save()
        HapticManager.selectionChanged()
    }
}
