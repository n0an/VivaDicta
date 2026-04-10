//
//  MultiNoteCreationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import SwiftUI
import SwiftData

/// Sheet for creating a new multi-note chat conversation.
///
/// Shows a selectable notes list with tag filter chips above,
/// mirroring the main screen's selection mode UX.
struct MultiNoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Transcription.timestamp, order: .reverse)
    private var allTranscriptions: [Transcription]

    @Query(sort: \TranscriptionTag.sortOrder)
    private var allTags: [TranscriptionTag]

    var onCreate: (MultiNoteConversation) -> Void

    @State private var selectedSourceTags: Set<String> = []
    @State private var selectedUserTagIds: Set<UUID> = []
    @State private var selectedNoteIds: Set<UUID> = []

    // MARK: - Computed

    private var availableSourceTags: [String] {
        var seen = Set<String>()
        return allTranscriptions.compactMap(\.sourceTag).filter { seen.insert($0).inserted }
    }

    private var hasActiveTagFilter: Bool {
        !selectedSourceTags.isEmpty || !selectedUserTagIds.isEmpty
    }

    private var displayedTranscriptions: [Transcription] {
        guard hasActiveTagFilter else { return allTranscriptions }
        return allTranscriptions.filter { transcription in
            let matchesSource = selectedSourceTags.isEmpty ||
                (transcription.sourceTag.map { selectedSourceTags.contains($0) } ?? false)
            let matchesUserTag = selectedUserTagIds.isEmpty ||
                (transcription.tagAssignments ?? []).contains { selectedUserTagIds.contains($0.tagId) }
            return matchesSource && matchesUserTag
        }
    }

    private var displayedIds: Set<UUID> {
        Set(displayedTranscriptions.map(\.id))
    }

    private var allDisplayedSelected: Bool {
        !displayedIds.isEmpty && displayedIds.isSubset(of: selectedNoteIds)
    }

    private var selectedTranscriptions: [Transcription] {
        allTranscriptions.filter { selectedNoteIds.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tag filter bar
                if !availableSourceTags.isEmpty || !allTags.isEmpty {
                    TagFilterBar(
                        sourceTags: availableSourceTags,
                        userTags: allTags,
                        selectedSourceTags: $selectedSourceTags,
                        selectedUserTagIds: $selectedUserTagIds
                    )
                    .padding(.vertical, 8)
                }

                // Selection header
                HStack {
                    Button {
                        toggleSelectAll()
                    } label: {
                        Text(allDisplayedSelected ? "Deselect All" : "Select All")
                            .font(.subheadline)
                    }

                    Spacer()

                    Text("^[\(selectedNoteIds.count) note](inflect: true) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                // Notes list
                List {
                    ForEach(displayedTranscriptions, id: \.id) { transcription in
                        selectableNoteRow(transcription)
                    }
                }
                .listStyle(.plain)

                createButton
            }
            .navigationTitle("New Multi-Note Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Selectable Row

    private func selectableNoteRow(_ transcription: Transcription) -> some View {
        let isSelected = selectedNoteIds.contains(transcription.id)
        return Button {
            if isSelected {
                selectedNoteIds.remove(transcription.id)
            } else {
                selectedNoteIds.insert(transcription.id)
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(transcription.text)
                        .font(.subheadline)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Select All

    private func toggleSelectAll() {
        if allDisplayedSelected {
            selectedNoteIds.subtract(displayedIds)
        } else {
            selectedNoteIds.formUnion(displayedIds)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                createConversation()
            } label: {
                Text("Start Chat")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedNoteIds.isEmpty)
            .padding()
        }
        .background(.bar)
    }

    private func createConversation() {
        let selected = selectedTranscriptions
        guard !selected.isEmpty else { return }

        let conversation = MultiNoteConversation()
        conversation.selectionMode = selected.count == allTranscriptions.count ? "all" : "manual"
        conversation.title = "\(selected.count) selected notes"
        modelContext.insert(conversation)

        for transcription in selected {
            let source = MultiNoteSource(transcription: transcription)
            source.conversation = conversation
            modelContext.insert(source)
        }

        try? modelContext.save()

        dismiss()
        onCreate(conversation)
    }
}
