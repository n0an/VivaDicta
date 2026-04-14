//
//  ChatInputBar.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import SwiftUI

/// Text input bar with send/stop button for the chat.
struct ChatInputBar: View {
    @Binding var text: String
    var isStreaming: Bool
    var isBusy: Bool = false
    var placeholder: String = "Ask about this note..."
    var secondaryActionTitle: String? = nil
    var isSecondaryActionArmed: Bool = false
    var isSecondaryActionEnabled: Bool = true
    var onSend: () -> Void
    var onStop: () -> Void
    var onSecondaryAction: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        if #available(iOS 26, *) {
            glassInputBar
        } else {
            legacyInputBar
        }
    }

    @available(iOS 26, *)
    private var glassInputBar: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                if let secondaryActionTitle, let onSecondaryAction {
                    secondaryActionButton(
                        title: secondaryActionTitle,
                        isArmed: isSecondaryActionArmed,
                        action: onSecondaryAction
                    )
                }

                HStack(alignment: .bottom, spacing: 12) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(1...6)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))

                    Button {
                        if isStreaming {
                            onStop()
                        } else {
                            onSend()
                        }
                    } label: {
                        Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend && !isStreaming)
                    .padding(8)
                    .glassEffect(
                        .regular
                            .tint(canSend || isStreaming ? Color.accentColor : .secondary)
                            .interactive(true),
                        in: .circle
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.18), radius: 8, y: -3)
        }
    }

    private var legacyInputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let secondaryActionTitle, let onSecondaryAction {
                secondaryActionButton(
                    title: secondaryActionTitle,
                    isArmed: isSecondaryActionArmed,
                    action: onSecondaryAction
                )
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(.rect(cornerRadius: 20))

                Button {
                    if isStreaming {
                        onStop()
                    } else {
                        onSend()
                    }
                } label: {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend || isStreaming ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isStreaming)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.18), radius: 8, y: -3)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming && !isBusy
    }

    @ViewBuilder
    private func secondaryActionButton(
        title: String,
        isArmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: "sparkle.magnifyingglass")
                .font(.caption)
                .foregroundStyle(isArmed ? .blue : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassCapsule(
                    tint: isArmed ? Color.blue.opacity(0.25) : nil,
                    fallback: isArmed ? Color.blue.opacity(0.12) : Color(.systemGray5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isSecondaryActionEnabled || isStreaming || isBusy)
    }
}
