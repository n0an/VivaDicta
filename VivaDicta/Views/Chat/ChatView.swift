//
//  ChatView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import SwiftUI
import SwiftData

private struct ChatSourceCitationDisplay: Identifiable {
    let transcription: Transcription
    let citation: SmartSearchSourceCitation?

    var id: UUID { transcription.id }
}

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
    @State private var selectedTranscription: Transcription?
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Transcription.timestamp, order: .reverse)
    private var allTranscriptions: [Transcription]

    var body: some View {
        if embedded {
            chatContent
        } else {
            NavigationStack {
                chatContent
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close")
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
                secondaryActionTitle: viewModel.isCrossNoteSearchArmed ? "Will search other notes" : "Search other notes",
                isSecondaryActionArmed: viewModel.isCrossNoteSearchArmed,
                onSend: { viewModel.sendMessage() },
                onStop: { viewModel.cancelStreaming() },
                onSecondaryAction: { viewModel.toggleCrossNoteSearchArmed() }
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
        .sheet(item: $selectedTranscription) { transcription in
            NavigationStack {
                TranscriptionDetailView(transcription: transcription)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                selectedTranscription = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close")
                        }
                    }
            }
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
                        VStack(alignment: .leading, spacing: 4) {
                            ChatBubbleView(message: message)

                            if message.role == "assistant" && !message.isError {
                                sourceCitationPills(for: message)
                            }
                        }
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
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
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
                    .bubbleBackground(isUser: false, isError: false)

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

                Group {
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 6) {
                            headerPills
                        }
                    } else {
                        headerPills
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
        }
    }

    private var headerPills: some View {
        let ratio = viewModel.contextFillRatio
        let percentage = Int(ratio * 100)

        return HStack(spacing: 6) {
            Button {
                selectedTranscription = viewModel.transcription
            } label: {
                Label("1 note", systemImage: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassCapsule(fallback: Color.secondary.opacity(0.1))
            }

            Text("\(percentage)%")
                .font(.caption2)
                .foregroundStyle(ratio > 0.7 ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassCapsule(
                    tint: ratio > 0.7 ? Color.orange.opacity(0.35) : nil,
                    fallback: (ratio > 0.7 ? Color.orange : Color.secondary).opacity(0.1)
                )
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

    @ViewBuilder
    private func sourceCitationPills(for message: ChatMessage) -> some View {
        let sources = resolveCitationDisplays(for: message)
        if !sources.isEmpty {
            ScrollView(.horizontal) {
                Group {
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 6) {
                            citationPillRow(for: sources)
                        }
                    } else {
                        citationPillRow(for: sources)
                    }
                }
                .padding(.leading)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func citationPillRow(for sources: [ChatSourceCitationDisplay]) -> some View {
        HStack(spacing: 6) {
            ForEach(sources) { source in
                Button {
                    selectedTranscription = source.transcription
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                        Text(sourceLabel(for: source))
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassCapsule(
                        tint: Color.indigo.opacity(colorScheme == .dark ? 0.2 : 0.7),
                        fallback: Color.secondary.opacity(0.3)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sourceLabel(for source: ChatSourceCitationDisplay) -> String {
        let date = source.transcription.timestamp.formatted(date: .abbreviated, time: .omitted)

        if let citation = source.citation {
            return "\(date) - \(excerptPreview(citation.excerpt))"
        }

        let title = source.transcription.text
            .prefix(30)
            .components(separatedBy: .newlines)
            .first ?? "Note"
        return "\(date) - \(title)"
    }

    private func excerptPreview(_ excerpt: String) -> String {
        let flattened = excerpt
            .replacing("\n", with: " ")
            .replacing("\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard flattened.count > 44 else { return flattened }
        return String(flattened.prefix(44)) + "..."
    }

    private func resolveSourceTranscriptions(ids: [UUID]) -> [Transcription] {
        let idSet = Set(ids)
        return allTranscriptions.filter { idSet.contains($0.id) }
    }

    private func resolveCitationDisplays(for message: ChatMessage) -> [ChatSourceCitationDisplay] {
        let citations = message.sourceCitations
        if !citations.isEmpty {
            let transcriptionMap = Dictionary(uniqueKeysWithValues: allTranscriptions.map { ($0.id, $0) })
            return citations
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .compactMap { citation in
                    guard let transcription = transcriptionMap[citation.transcriptionId] else {
                        return nil
                    }
                    return ChatSourceCitationDisplay(transcription: transcription, citation: citation)
                }
        }

        return resolveSourceTranscriptions(ids: message.sourceTranscriptionIds).map { transcription in
            ChatSourceCitationDisplay(transcription: transcription, citation: nil)
        }
    }
}
