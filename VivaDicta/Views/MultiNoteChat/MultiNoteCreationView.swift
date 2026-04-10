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
        VStack(spacing: 0) {
            Text("Select notes to start a conversation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 2)

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
    }

    // MARK: - Selectable Row

    private var assignedTagsLookup: [UUID: [TranscriptionTag]] {
        var result: [UUID: [TranscriptionTag]] = [:]
        for transcription in displayedTranscriptions {
            let assignedIds = Set((transcription.tagAssignments ?? []).map(\.tagId))
            result[transcription.id] = allTags.filter { assignedIds.contains($0.id) }
        }
        return result
    }

    private func selectableNoteRow(_ transcription: Transcription) -> some View {
        let isSelected = selectedNoteIds.contains(transcription.id)
        let tags = assignedTagsLookup[transcription.id] ?? []

        return Button {
            if isSelected {
                selectedNoteIds.remove(transcription.id)
            } else {
                selectedNoteIds.insert(transcription.id)
            }
        } label: {
            HStack(alignment: .center) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        if let tag = transcription.sourceTag {
                            Image(systemName: SourceTag.icon(for: tag))
                                .font(.caption2)
                                .foregroundStyle(SourceTag.color(for: tag))
                        }
                    }

                    Text(transcription.enhancedText ?? transcription.text)
                        .font(.body)
                        .lineLimit(2)
                        .lineSpacing(2)

                    if !tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tags.prefix(5)) { tag in
                                Image(systemName: tag.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: tag.colorHex) ?? .blue)
                                    .frame(width: 22, height: 22)
                                    .background((Color(hex: tag.colorHex) ?? .blue).opacity(0.15))
                                    .clipShape(.circle)
                            }
                            if tags.count > 5 {
                                Text("+\(tags.count - 5)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Text(transcription.getDurationFormatted(transcription.audioDuration))
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(.rect(cornerRadius: 6))
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
        conversation.title = "\(selected.count) selected notes"
        conversation.noteContext = MultiNoteContextManager.assembleNoteText(from: selected)
        conversation.sourceNoteCount = selected.count
        modelContext.insert(conversation)

        try? modelContext.save()

        onCreate(conversation)
    }
}
