//
//  MultiNoteChatsListView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import SwiftUI
import SwiftData

/// List of multi-note chat conversations.
struct MultiNoteChatsListView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: MultiNoteChatsListViewModel?
    @State private var showCreation = false
    @State private var showChat = false
    @State private var chatViewModel: MultiNoteChatViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, !viewModel.conversations.isEmpty {
                    conversationsList(viewModel.conversations)
                } else {
                    ContentUnavailableView(
                        "No Multi-Note Chats",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Create a chat to discuss multiple notes with AI")
                    )
                }
            }
            .navigationTitle("Multi-Note Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Chat", systemImage: "plus") {
                        showCreation = true
                    }
                }
            }
            .sheet(isPresented: $showCreation) {
                MultiNoteCreationView { conversation in
                    viewModel?.loadConversations()
                    openChat(for: conversation)
                }
            }
            .sheet(isPresented: $showChat, onDismiss: {
                viewModel?.loadConversations()
                chatViewModel = nil
            }) {
                if let chatViewModel {
                    MultiNoteChatView(viewModel: chatViewModel)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = MultiNoteChatsListViewModel(modelContext: modelContext)
                }
            }
        }
    }

    private func conversationsList(_ conversations: [MultiNoteConversation]) -> some View {
        List {
            ForEach(conversations, id: \.id) { conversation in
                Button {
                    openChat(for: conversation)
                } label: {
                    conversationRow(conversation)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel?.deleteConversation(conversations[index])
                }
            }
        }
    }

    private struct ConversationRowContent: View {
        let title: String
        let noteCount: Int
        let lastMessage: String?
        let date: Date

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(date, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Label("^[\(noteCount) note](inflect: true)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func openChat(for conversation: MultiNoteConversation) {
        chatViewModel = MultiNoteChatViewModel(
            conversation: conversation,
            aiService: appState.aiService,
            modelContext: modelContext
        )
        showChat = true
    }

    private func conversationRow(_ conversation: MultiNoteConversation) -> some View {
        let noteCount = conversation.sourceNoteCount
        let lastMessage = (conversation.messages ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .last
            .map { $0.role == "user" ? "You: \($0.content)" : $0.content }

        return ConversationRowContent(
            title: conversation.title.isEmpty ? "Untitled Chat" : conversation.title,
            noteCount: noteCount,
            lastMessage: lastMessage,
            date: conversation.createdAt
        )
    }
}
