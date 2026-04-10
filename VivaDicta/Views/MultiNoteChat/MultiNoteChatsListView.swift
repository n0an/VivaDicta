//
//  MultiNoteChatsListView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import SwiftUI
import SwiftData

/// List of chat conversations with a segmented control to switch
/// between multi-note and single-note chats.
struct MultiNoteChatsListView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ChatsListViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: ChatTab = .multiNote

    enum ChatTab: String, CaseIterable {
        case multiNote = "Multi-Note"
        case singleNote = "Single-Note"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Picker("Chat Type", selection: $selectedTab) {
                    ForEach(ChatTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    switch selectedTab {
                    case .multiNote:
                        multiNoteContent
                    case .singleNote:
                        singleNoteContent
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if selectedTab == .multiNote {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Chat", systemImage: "plus") {
                            navigationPath.append(NavigationTarget.creation)
                        }
                    }
                }
            }
            .navigationDestination(for: NavigationTarget.self) { target in
                switch target {
                case .creation:
                    MultiNoteCreationView { conversation in
                        viewModel?.loadMultiNote()
                        navigationPath.removeLast()
                        navigationPath.append(NavigationTarget.multiNoteChat(conversation.id))
                    }
                case .multiNoteChat(let conversationId):
                    if let conversation = viewModel?.multiNoteConversations.first(where: { $0.id == conversationId }) {
                        MultiNoteChatView(
                            viewModel: MultiNoteChatViewModel(
                                conversation: conversation,
                                aiService: appState.aiService,
                                modelContext: modelContext
                            )
                        )
                    }
                case .singleNoteChat(let conversationId):
                    if let conversation = viewModel?.singleNoteConversations.first(where: { $0.id == conversationId }),
                       let transcription = conversation.transcription {
                        ChatView(
                            viewModel: ChatViewModel(
                                conversation: conversation,
                                transcription: transcription,
                                aiService: appState.aiService,
                                modelContext: modelContext
                            ),
                            embedded: true
                        )
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ChatsListViewModel(modelContext: modelContext)
                }
            }
            .onChange(of: navigationPath.count) {
                if navigationPath.isEmpty {
                    viewModel?.loadAll()
                }
            }
        }
    }

    // MARK: - Navigation

    private enum NavigationTarget: Hashable {
        case creation
        case multiNoteChat(UUID)
        case singleNoteChat(UUID)
    }

    // MARK: - Multi-Note Content

    private var multiNoteContent: some View {
        Group {
            if let viewModel, !viewModel.multiNoteConversations.isEmpty {
                List {
                    ForEach(viewModel.multiNoteConversations, id: \.id) { conversation in
                        Button {
                            navigationPath.append(NavigationTarget.multiNoteChat(conversation.id))
                        } label: {
                            multiNoteRow(conversation)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteMultiNoteConversation(viewModel.multiNoteConversations[index])
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Multi-Note Chats",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Create a chat to discuss multiple notes with AI")
                )
            }
        }
    }

    // MARK: - Single-Note Content

    private var singleNoteContent: some View {
        Group {
            if let viewModel, !viewModel.singleNoteConversations.isEmpty {
                List {
                    ForEach(viewModel.singleNoteConversations, id: \.id) { conversation in
                        Button {
                            navigationPath.append(NavigationTarget.singleNoteChat(conversation.id))
                        } label: {
                            singleNoteRow(conversation)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteSingleNoteConversation(viewModel.singleNoteConversations[index])
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Single-Note Chats",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("Start a chat from any note's detail view")
                )
            }
        }
    }

    // MARK: - Row Views

    private func multiNoteRow(_ conversation: MultiNoteConversation) -> some View {
        let noteCount = conversation.sourceNoteCount
        let lastMessage = (conversation.messages ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .last
            .map { $0.role == "user" ? "You: \($0.content)" : $0.content }

        return ChatRowContent(
            title: conversation.title.isEmpty ? "Untitled Chat" : conversation.title,
            subtitle: "^[\(noteCount) note](inflect: true)",
            subtitleIcon: "doc.text",
            lastMessage: lastMessage,
            date: conversation.createdAt
        )
    }

    private func singleNoteRow(_ conversation: ChatConversation) -> some View {
        let noteTitle = conversation.transcription.map { transcription in
            let text = transcription.text
            return String(text.prefix(60)) + (text.count > 60 ? "..." : "")
        } ?? "Deleted Note"

        let lastMessage = (conversation.messages ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .last
            .map { $0.role == "user" ? "You: \($0.content)" : $0.content }

        return ChatRowContent(
            title: noteTitle,
            subtitle: nil,
            subtitleIcon: nil,
            lastMessage: lastMessage,
            date: conversation.createdAt
        )
    }
}

// MARK: - Shared Row

private struct ChatRowContent: View {
    let title: String
    let subtitle: String?
    let subtitleIcon: String?
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

            if let subtitle {
                HStack(spacing: 4) {
                    if let icon = subtitleIcon {
                        Label {
                            Text(.init(subtitle))
                        } icon: {
                            Image(systemName: icon)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
