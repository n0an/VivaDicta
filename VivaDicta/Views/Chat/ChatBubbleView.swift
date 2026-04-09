//
//  ChatBubbleView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import SwiftUI

/// A single message bubble in the chat conversation.
struct ChatBubbleView: View {
    let message: ChatMessage
    var isStreamingThis: Bool = false
    var streamingText: String = ""

    var body: some View {
        if message.isSummary {
            summaryCard
        } else {
            messageBubble
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        Label("Previous conversation compacted", systemImage: "arrow.trianglehead.2.clockwise")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    // MARK: - Message Bubble

    private var messageBubble: some View {
        let isUser = message.role == "user"
        let isError = message.isError

        return HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Group {
                    if isUser {
                        Text(displayText)
                    } else {
                        Text(.init(displayText))
                    }
                }
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground(isUser: isUser, isError: isError))
                .foregroundStyle(isUser ? .white : (isError ? .red : .primary))
                .clipShape(.rect(cornerRadius: 18))

                if !isUser, let modelName = message.aiModelName {
                    Text(modelName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }

    private var displayText: String {
        if isStreamingThis, !streamingText.isEmpty {
            return streamingText
        }
        return message.content
    }

    private func bubbleBackground(isUser: Bool, isError: Bool) -> some ShapeStyle {
        if isError {
            return AnyShapeStyle(Color.red.opacity(0.15))
        }
        if isUser {
            return AnyShapeStyle(Color.accentColor)
        }
        return AnyShapeStyle(Color(.systemGray5))
    }
}
