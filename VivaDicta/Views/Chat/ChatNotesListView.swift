//
//  ChatNotesListView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import SwiftUI

/// Shows the transcription notes linked to a chat conversation.
///
/// Works for both single-note (``ChatConversation``) and multi-note
/// (``MultiNoteConversation``) chats. Tapping a note opens a read-only
/// preview sheet so the user stays in the chat flow.
struct ChatNotesListView: View {
    let transcriptions: [Transcription]

    /// Total number of notes originally included (may differ from
    /// `transcriptions.count` if some were deleted).
    let originalCount: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if transcriptions.isEmpty {
                    ContentUnavailableView(
                        "Notes Unavailable",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("The linked notes have been deleted.")
                    )
                } else {
                    if transcriptions.count < originalCount {
                        let deleted = originalCount - transcriptions.count
                        Section {
                            Label(
                                "^[\(deleted) note](inflect: true) no longer available",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        ForEach(transcriptions) { transcription in
                            NavigationLink(value: transcription) {
                                NoteRow(transcription: transcription)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("^[\(originalCount) Linked Note](inflect: true)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: Transcription.self) { transcription in
                TranscriptionDetailView(transcription: transcription)
            }
        }
    }
}

// MARK: - Note Row

private struct NoteRow: View {
    let transcription: Transcription

    private var displayText: String {
        transcription.enhancedText ?? transcription.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(displayText)
                .font(.body)
                .lineLimit(3)
                .lineSpacing(2)

            if transcription.audioDuration > 0 {
                Text(transcription.getDurationFormatted(transcription.audioDuration))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(.rect(cornerRadius: 4))
            }
        }
        .padding(.vertical, 4)
    }
}
