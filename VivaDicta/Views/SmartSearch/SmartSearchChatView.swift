//
//  SmartSearchChatView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import SwiftUI
import SwiftData

private struct SmartSearchCitationDisplay: Identifiable {
    let transcription: Transcription
    let citation: SmartSearchSourceCitation?

    var id: UUID { transcription.id }
}

/// Chat view for RAG-powered Smart Search conversations.
///
/// Mirrors ``MultiNoteChatView`` structure but adds source citation pills
/// below assistant messages and shows indexing status instead of note count.
struct SmartSearchChatView: View {
    @State var viewModel: SmartSearchChatViewModel
    @State private var ragService = RAGIndexingService.shared

    @State private var showClearConfirmation = false
    @State private var selectedTranscription: Transcription?
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Transcription.timestamp, order: .reverse)
    private var allTranscriptions: [Transcription]

    var body: some View {
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
                placeholder: "Search your notes...",
                onSend: { viewModel.sendMessage() },
                onStop: { viewModel.cancelStreaming() }
            )
        }
        .navigationTitle("Smart Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.messages.isEmpty || viewModel.isStreaming)
            }
        }
        .alert("Delete Conversation?", isPresented: $showClearConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.clearChat()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all messages in this Smart Search conversation. This cannot be undone.")
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
                                ChatToolUsageBadgeRow(
                                    didUseCrossNoteSearchTool: message.didUseCrossNoteSearchTool,
                                    didUseWebSearchTool: message.didUseWebSearchTool
                                )
                                sourceCitationPills(for: message)
                            }
                        }
                        .id(message.id)
                    }

                    if viewModel.isSearching {
                        searchingIndicator
                            .id("searching")
                    }

                    if isThinking && !viewModel.isSearching {
                        TypingIndicator()
                            .id("typing")
                    }

                    if viewModel.isStreaming, !viewModel.streamingText.isEmpty {
                        streamingBubble
                            .id("streaming")
                    }

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
            .onChange(of: viewModel.isSearching) {
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
            } else if viewModel.isSearching {
                proxy.scrollTo("searching", anchor: .bottom)
            } else if isThinking {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if viewModel.isCompacting {
                proxy.scrollTo("compacting", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Smart Search", systemImage: "sparkle.magnifyingglass")
        } description: {
            Text("Ask questions about your notes. AI-powered semantic search finds relevant notes automatically.")
        }
        .padding(.top, 40)
    }

    // MARK: - Source Citation Pills

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
    private func citationPillRow(for sources: [SmartSearchCitationDisplay]) -> some View {
        HStack(spacing: 6) {
            ForEach(sources) { source in
                Button {
                    selectedTranscription = source.transcription
                    RateAppManager.requestReviewIfAppropriate()
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

    private func sourceLabel(for source: SmartSearchCitationDisplay) -> String {
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

    private func resolveCitationDisplays(for message: ChatMessage) -> [SmartSearchCitationDisplay] {
        let citations = message.sourceCitations
        if !citations.isEmpty {
            let transcriptionMap = Dictionary(uniqueKeysWithValues: allTranscriptions.map { ($0.id, $0) })
            return citations
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .compactMap { citation in
                guard let transcription = transcriptionMap[citation.transcriptionId] else {
                    return nil
                }
                return SmartSearchCitationDisplay(
                    transcription: transcription,
                    citation: citation
                )
            }
        }

        return resolveSourceTranscriptions(ids: message.sourceTranscriptionIds).map { transcription in
            SmartSearchCitationDisplay(
                transcription: transcription,
                citation: nil
            )
        }
    }

    // MARK: - Streaming & Indicators

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

    private var searchingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Searching notes...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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

    // MARK: - Header Bar

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

                indexingStatusPill

                let ratio = viewModel.contextFillRatio
                let percentage = Int(ratio * 100)
                if ratio > 0 {
                    Text("\(percentage)%")
                        .font(.caption2)
                        .foregroundStyle(ratio > 0.7 ? .orange : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((ratio > 0.7 ? Color.orange : Color.secondary).opacity(0.1))
                        .clipShape(.capsule)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
        }
    }

    private var indexingStatusPill: some View {
        let count = ragService.indexedTranscriptionCount

        return HStack(spacing: 4) {
            if ragService.isIndexing {
                ProgressView()
                    .controlSize(.mini)
                Text("Indexing...")
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                Text("^[\(count) note](inflect: true)")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .clipShape(.capsule)
    }
}
