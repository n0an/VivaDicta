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
                        Text(message.content)
                    } else {
                        Text(.init(message.content))
                    }
                }
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isUser ? .white : (isError ? .red : .primary))
                .bubbleBackground(isUser: isUser, isError: isError)

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

}

// MARK: - Bubble Background Modifier

private struct BubbleBackgroundModifier: ViewModifier {
    let isUser: Bool
    let isError: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(glassTint),
                    in: .rect(cornerRadius: 18)
                )
        } else {
            content
                .background(legacyBackground)
                .clipShape(.rect(cornerRadius: 18))
        }
    }

    @available(iOS 26, *)
    private var glassTint: Color {
        if isError { return .red.opacity(0.3) }
        if isUser { return .accentColor }
        return .gray.opacity(0.3)
    }

    private var legacyBackground: AnyShapeStyle {
        if isError { return AnyShapeStyle(Color.red.opacity(0.15)) }
        if isUser { return AnyShapeStyle(Color.accentColor) }
        return AnyShapeStyle(Color(.systemGray5))
    }
}

extension View {
    func bubbleBackground(isUser: Bool, isError: Bool) -> some View {
        modifier(BubbleBackgroundModifier(isUser: isUser, isError: isError))
    }
}
