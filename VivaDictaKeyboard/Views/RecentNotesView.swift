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
    @Environment(\.colorScheme) private var colorScheme

    let onNoteSelected: (String) -> Void

    let onOpenApp: () -> Void
    let onBackspace: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void
    /// Called with the number of characters to delete (revert last paste).
    let onRevert: (Int) -> Void

    private let displayLimit = 5
    @State private var notes: [RecentNote] = []
    /// Stack of pasted note lengths for multi-level revert.
    @State private var pastedLengths: [Int] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header: switcher on left, utility buttons on right
            HStack {
                KeyboardTabToggle(dictationState: dictationState)

                Spacer()

                // Utility buttons: space, return, backspace
                HStack(spacing: 4) {

                    if !pastedLengths.isEmpty {
                        Button {
                            HapticManager.lightImpact()
                            if let last = pastedLengths.last {
                                onRevert(last)
                                withAnimation { _ = pastedLengths.removeLast() }
                            }
                        } label: {
                            revertButtonLabel
                        }
                        .buttonStyle(.plain)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                        .transition(.scale.combined(with: .opacity))
                    }

                    utilityButton(icon: "space", color: .blue, action: onSpace)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                    utilityButton(icon: "return", color: .blue, action: onNewline)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                    utilityButton(icon: "delete.backward", color: .red, action: onBackspace)
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
                        withAnimation { pastedLengths.append(note.text.count) }
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
        .background(colorScheme == .dark ? Color( .quaternarySystemFill).opacity(0.5) : Color.white, in: .rect(cornerRadius: 10))
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
    
    enum UtilityButtonPlacement {
        case first
        case mid
        case last
    }

    @ViewBuilder
    private func utilityButton(
        icon: String,
        color: Color,
        placement: UtilityButtonPlacement = .mid,
        action: @escaping () -> Void) -> some View {
            
//            let isBackspace = icon == "delete.backward"
//            let tintColor: Color = isBackspace ? .red : .blue
            if #available(iOS 26.0, *) {
                RepeatableButton(action: action) {
                    utilityButtonLabel(icon: icon)
                        .frame(width: 36, height: 20)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .glassEffect(.regular.tint(color.opacity(0.3)).interactive())
                .padding(.trailing, placement == .first ? 4 : 0)
                .padding(.trailing, placement == .last ? 0 : 4)
            } else {
                RepeatableButton(action: action) {
                    utilityButtonLabel(icon: icon)
                        .frame(width: 40, height: 24)
                        .background(color.opacity(0.5), in: .capsule(style: .continuous))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
        }

    @ViewBuilder
    private var revertButtonLabel: some View {
        if #available(iOS 26.0, *) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 20)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .glassEffect(.regular.tint(Color.yellow.opacity(0.3)).interactive())
        } else {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 24)
                .background(Color.yellow.opacity(0.5), in: .capsule(style: .continuous))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
    }

    private func utilityButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .contentShape(.rect)
    }
}
