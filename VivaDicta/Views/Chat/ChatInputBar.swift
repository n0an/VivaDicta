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
    var onSend: () -> Void
    var onStop: () -> Void

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
}
