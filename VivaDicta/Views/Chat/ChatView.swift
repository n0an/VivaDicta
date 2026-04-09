//
//  ChatView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import SwiftUI
import SwiftData

/// Main "Chat with Note" sheet view.
///
/// Presents a conversation interface where users can chat with AI about
/// their transcription note. Supports streaming responses, provider/model
/// selection, and context compaction.
struct ChatView: View {
    @State var viewModel: ChatViewModel
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChatProviderPickerView(
                    viewModel: viewModel,
                    aiService: appState.aiService
                )

                messagesList

                ChatInputBar(
                    text: $viewModel.inputText,
                    isStreaming: viewModel.isStreaming || viewModel.isAppleFMResponding,
                    onSend: { viewModel.sendMessage() },
                    onStop: { viewModel.cancelStreaming() }
                )
            }
            .navigationTitle("Chat")
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
                Text("This will delete all chat messages for this note. This cannot be undone.")
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

                // Streaming bubble
                if viewModel.isStreaming, !viewModel.streamingText.isEmpty {
                    streamingBubble
                }

                // Compacting indicator
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
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Ask anything about this note")
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
