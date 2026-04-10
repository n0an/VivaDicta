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
        VStack(spacing: 0) {
            Divider()
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
                        .foregroundStyle(canSend || isStreaming ? Color.accentColor : Color(.systemGray4))
                }
                .disabled(!canSend && !isStreaming)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming && !isBusy
    }
}
