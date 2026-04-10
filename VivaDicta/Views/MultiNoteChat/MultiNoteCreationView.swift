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
/// Supports three note selection modes:
/// - All Notes: includes every transcription
/// - By Tags: filter by one or more user tags
/// - Pick Notes: manual selection from a searchable list
struct MultiNoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Transcription.timestamp, order: .reverse)
    private var allTranscriptions: [Transcription]

    @Query(sort: \TranscriptionTag.sortOrder)
    private var allTags: [TranscriptionTag]

    var onCreate: (MultiNoteConversation) -> Void

    @State private var selectionMode: NoteSelectionMode = .allNotes
    @State private var selectedTagIds: Set<UUID> = []
    @State private var selectedNoteIds: Set<UUID> = []
    @State private var searchText = ""

    enum NoteSelectionMode: String, CaseIterable {
        case allNotes = "All Notes"
        case byTags = "By Tags"
        case pickNotes = "Pick Notes"
    }

    private var matchingTranscriptions: [Transcription] {
        switch selectionMode {
        case .allNotes:
            return allTranscriptions
        case .byTags:
            guard !selectedTagIds.isEmpty else { return [] }
            return allTranscriptions.filter { transcription in
                guard let assignments = transcription.tagAssignments else { return false }
                return assignments.contains { selectedTagIds.contains($0.tagId) }
            }
        case .pickNotes:
            return allTranscriptions.filter { selectedNoteIds.contains($0.id) }
        }
    }

    private var canCreate: Bool {
        !matchingTranscriptions.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Selection Mode", selection: $selectionMode) {
                    ForEach(NoteSelectionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectionMode {
                case .allNotes:
                    allNotesSection
                case .byTags:
                    tagSelectionSection
                case .pickNotes:
                    noteSelectionSection
                }

                Spacer()

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

    // MARK: - All Notes

    private var allNotesSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("^[\(allTranscriptions.count) note](inflect: true) will be included")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Tag Selection

    private var tagSelectionSection: some View {
        VStack(spacing: 0) {
            if allTags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag",
                    description: Text("Create tags in Settings to filter notes")
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.id) { tag in
                            tagChip(tag)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)

                if !selectedTagIds.isEmpty {
                    let count = matchingTranscriptions.count
                    Text("^[\(count) matching note](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }

                if !matchingTranscriptions.isEmpty {
                    notePreviewList(matchingTranscriptions)
                }
            }
        }
    }

    private func tagChip(_ tag: TranscriptionTag) -> some View {
        let isSelected = selectedTagIds.contains(tag.id)
        return Button {
            if isSelected {
                selectedTagIds.remove(tag.id)
            } else {
                selectedTagIds.insert(tag.id)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tag.icon)
                    .font(.caption2)
                Text(tag.name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(.capsule)
        }
    }

    // MARK: - Manual Note Selection

    private var noteSelectionSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search notes", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 10))
            .padding(.horizontal)

            let filtered = searchText.isEmpty
                ? allTranscriptions
                : allTranscriptions.filter { $0.text.localizedStandardContains(searchText) }

            if !selectedNoteIds.isEmpty {
                Text("^[\(selectedNoteIds.count) note](inflect: true) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            List {
                ForEach(filtered, id: \.id) { transcription in
                    selectableNoteRow(transcription)
                }
            }
            .listStyle(.plain)
        }
    }

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

    // MARK: - Note Preview List

    private func notePreviewList(_ transcriptions: [Transcription]) -> some View {
        List {
            ForEach(transcriptions, id: \.id) { transcription in
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
        .listStyle(.plain)
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
            .disabled(!canCreate)
            .padding()
        }
        .background(.bar)
    }

    private func createConversation() {
        let conversation = MultiNoteConversation()
        conversation.selectionMode = selectionMode.rawValue

        // Generate title
        switch selectionMode {
        case .allNotes:
            conversation.title = "All Notes (\(matchingTranscriptions.count))"
        case .byTags:
            let tagNames = allTags
                .filter { selectedTagIds.contains($0.id) }
                .map(\.name)
                .joined(separator: ", ")
            conversation.title = "\(tagNames) (\(matchingTranscriptions.count) notes)"

            if let data = try? JSONEncoder().encode(Array(selectedTagIds)) {
                conversation.tagFilterData = data
            }
        case .pickNotes:
            conversation.title = "\(matchingTranscriptions.count) selected notes"
        }

        modelContext.insert(conversation)

        // Create junction records
        for transcription in matchingTranscriptions {
            let source = MultiNoteSource(transcription: transcription)
            source.conversation = conversation
            modelContext.insert(source)
        }

        try? modelContext.save()

        dismiss()
        onCreate(conversation)
    }
}
