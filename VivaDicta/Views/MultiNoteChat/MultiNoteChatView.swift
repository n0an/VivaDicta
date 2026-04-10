//
//  MultiNoteChatView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import SwiftUI

/// Chat view for multi-note conversations.
///
/// Mirrors ``ChatView`` structure, reusing ``ChatBubbleView`` and ``ChatInputBar``.
struct MultiNoteChatView: View {
    @State var viewModel: MultiNoteChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatHeaderBar

                messagesList

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                }

                ChatInputBar(
                    text: $viewModel.inputText,
                    isStreaming: viewModel.isStreaming || viewModel.isAppleFMResponding,
                    placeholder: "Ask about these notes...",
                    onSend: { viewModel.sendMessage() },
                    onStop: { viewModel.cancelStreaming() }
                )
            }
            .navigationTitle("Multi-Note Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task { await viewModel.compactChat() }
                        } label: {
                            Label("Compact Chat", systemImage: "arrow.trianglehead.2.clockwise")
                        }
                        .disabled(viewModel.messages.count < 6 || viewModel.isStreaming || viewModel.isCompacting)

                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }
                        .disabled(viewModel.messages.isEmpty || viewModel.isStreaming)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Clear Chat?", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) {
                    viewModel.clearChat()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all chat messages. This cannot be undone.")
            }
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.messages.isEmpty && !viewModel.isStreaming {
                    emptyState
                }

                ForEach(viewModel.messages, id: \.id) { message in
                    ChatBubbleView(message: message)
                }

                if viewModel.isStreaming, !viewModel.streamingText.isEmpty {
                    streamingBubble
                }

                if viewModel.isCompacting {
                    compactingIndicator
                }
            }
            .padding(.vertical, 12)
        }
        .defaultScrollAnchor(.bottom)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Ask anything about these notes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var streamingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(.init(viewModel.streamingText))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(.rect(cornerRadius: 18))

                if let model = viewModel.selectedModel {
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 60)
        }
        .padding(.horizontal)
    }

    private var chatHeaderBar: some View {
        VStack(spacing: 0) {
            HStack {
                if let provider = viewModel.selectedProvider {
                    Text(provider.displayName)
                        .font(.subheadline)
                }
                if let model = viewModel.selectedModel {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Label("^[\(viewModel.conversation.sourceNoteCount) note](inflect: true)", systemImage: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                let ratio = viewModel.contextFillRatio
                let percentage = Int(ratio * 100)
                Text("\(percentage)%")
                    .font(.caption2)
                    .foregroundStyle(ratio > 0.7 ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((ratio > 0.7 ? Color.orange : Color.secondary).opacity(0.1))
                    .clipShape(.capsule)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
        }
    }

    private var compactingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Compacting conversation...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
