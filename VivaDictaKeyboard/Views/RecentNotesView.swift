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
    @Environment(\.openURL) private var openURL

    let onNoteSelected: (String) -> Void
    
    let onOpenApp: () -> Void
    let onBackspace: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void

    private let displayLimit = 5
    @State private var notes: [RecentNote] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header: switcher on left, utility buttons on right
            HStack {
                KeyboardTabToggle(dictationState: dictationState)

                Spacer()

                // Utility buttons: space, return, backspace
                HStack(spacing: 4) {
                    
                    utilityButton(icon: "space", action: onSpace)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                    utilityButton(icon: "return", action: onNewline)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                    utilityButton(icon: "delete.backward", action: onBackspace)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if notes.isEmpty {
                emptyStateView
            } else {
                notesListView
                    .padding(.horizontal, 24)
            }
        }
        .frame(height: 260)
        .onAppear {
            guard notes.isEmpty else { return }
            notes = Array(RecentNotesCache.loadNotes().prefix(displayLimit))
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
                                .padding(.bottom, 8)
                            
                            Divider()
//                            Text(note.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
//                                .font(.system(size: 11))
//                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
//                        .background(.primary, in: .rect(cornerRadius: 10))

//                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // Footer: open app for all notes
                VStack(spacing: 6) {
                    Text("To see all notes, open VivaDicta")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)

                    Button {
                        HapticManager.lightImpact()
                        if let url = URL(string: "vivadicta://") {
                            openURL(url)
                        }
                    } label: {
                        Label("Open VivaDicta", systemImage: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(.white, in: .rect(cornerRadius: 10))
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
    
    
    // MARK: - Utility Button

    @ViewBuilder
    private func utilityButton(icon: String, action: @escaping () -> Void) -> some View {
        let last = icon == "delete.backward"
        if #available(iOS 26.0, *) {
            
            Button {
                HapticManager.lightImpact()
                action()
            } label: {
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 20)
                    .contentShape(.rect)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .buttonStyle(.plain)
            .glassEffect(.regular.tint((last ? Color.red : .blue).opacity(0.3)).interactive())
            .padding(.trailing, (last ? 0 : 4))
        } else {
            Button {
                HapticManager.lightImpact()
                action()
            } label: {
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 24)
                    .background((last ? Color.red : .blue).opacity(0.5), in: .capsule(style: .continuous))
                    .contentShape(.rect)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .buttonStyle(.plain)
        }
    }
}
