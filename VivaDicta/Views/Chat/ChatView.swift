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
    /// When true, skips the NavigationStack wrapper (used when pushed from a parent NavigationStack).
    var embedded: Bool = false
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmation = false
    @State private var showScrollToBottom = false

    var body: some View {
        if embedded {
            chatContent
        } else {
            NavigationStack {
                chatContent
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
    }

    private var chatContent: some View {
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
                isBusy: viewModel.isCompacting,
                onSend: { viewModel.sendMessage() },
                onStop: { viewModel.cancelStreaming() }
            )
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

    // MARK: - Messages List

    /// Whether the model is thinking (waiting for first token or Apple FM responding).
    private var isThinking: Bool {
        (viewModel.isStreaming || viewModel.isAppleFMResponding) && viewModel.streamingText.isEmpty
    }

    private let bottomAnchorID = "bottomAnchor"

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty && !viewModel.isStreaming && !viewModel.isAppleFMResponding {
                        emptyState
                    }

                    ForEach(viewModel.messages, id: \.id) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                    }

                    // Typing indicator while model is thinking
                    if isThinking {
                        TypingIndicator()
                            .id("typing")
                    }

                    // Streaming bubble once text starts arriving
                    if viewModel.isStreaming, !viewModel.streamingText.isEmpty {
                        streamingBubble
                            .id("streaming")
                    }

                    // Compacting indicator
                    if viewModel.isCompacting {
                        compactingIndicator
                            .id("compacting")
                    }

                    Color.clear.frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { geo in
                let distanceFromBottom = geo.contentSize.height - (geo.contentOffset.y + geo.containerSize.height)
                return distanceFromBottom > geo.containerSize.height && geo.contentSize.height > geo.containerSize.height
            } action: { _, isScrolledUp in
                withAnimation {
                    showScrollToBottom = isScrolledUp
                }
            }
            .overlay(alignment: .bottom) {
                if showScrollToBottom {
                    ScrollToTopButton(backgroundColor: .blue) {
                        withAnimation {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .rotationEffect(.degrees(180))
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isThinking) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isCompacting) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isStreaming, !viewModel.streamingText.isEmpty {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if isThinking {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if viewModel.isCompacting {
                proxy.scrollTo("compacting", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
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
