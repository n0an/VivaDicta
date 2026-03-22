//
//  RecentNotesView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.22
//

import SwiftUI

/// Displays recent transcriptions in the keyboard for quick insertion.
///
/// Tapping a note inserts its text at the current cursor position in the host app.
struct RecentNotesView: View {
    @Environment(KeyboardDictationState.self) var dictationState

    let onNoteSelected: (String) -> Void

    @State private var notes: [RecentNote] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                KeyboardTabToggle(dictationState: dictationState)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if notes.isEmpty {
                emptyStateView
            } else {
                notesListView
            }
        }
        .onAppear {
            notes = RecentNotesCache.loadNotes()
        }
    }

    // MARK: - Notes List

    private var notesListView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(notes) { note in
                    Button {
                        HapticManager.mediumImpact()
                        onNoteSelected(note.text)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(note.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No recent notes")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Record a transcription to see it here")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }
}
