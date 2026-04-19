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
    @AppStorage(SmartSearchFeature.isEnabledKey) private var isSmartSearchEnabled = true

    @State private var viewModel: ChatsListViewModel?
    @State private var navigationPath = NavigationPath()
    @AppStorage("chatsLastSelectedTab") private var selectedTab: ChatTab = .multiNote
    @State private var cachedMultiNoteVMs: [UUID: MultiNoteChatViewModel] = [:]
    @State private var cachedSingleNoteVMs: [UUID: ChatViewModel] = [:]
    @State private var cachedSmartSearchVM: SmartSearchChatViewModel?

    enum ChatTab: String, CaseIterable {
        case allNotes = "Recent Notes"
        case multiNote = "Multi-Note"
        case singleNote = "Single-Note"
        case smartSearch = "Smart Search"
    }

    private var isAIConfigured: Bool {
        appState.aiService.isProperlyConfigured()
    }

    private var availableTabs: [ChatTab] {
        var tabs: [ChatTab] = [.allNotes, .multiNote, .singleNote]
        if isSmartSearchEnabled {
            tabs.append(.smartSearch)
        }
        return tabs
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if !isAIConfigured {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Set up an AI provider in mode settings to start new chats.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                }

                Picker("Chat Type", selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
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
                    case .allNotes:
                        allNotesContent
                    case .smartSearch:
                        smartSearchContent
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                if selectedTab == .multiNote {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Chat", systemImage: "plus") {
                            navigationPath.append(NavigationTarget.creation)
                        }
                        .disabled(!isAIConfigured)
                    }
                }
                if selectedTab == .allNotes {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Chat", systemImage: "plus") {
                            startNewAllNotesChat()
                        }
                        .disabled(!isAIConfigured)
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
                    if let conversation = viewModel?.multiNoteConversations.first(where: { $0.id == conversationId })
                        ?? viewModel?.allNotesConversations.first(where: { $0.id == conversationId }) {
                        MultiNoteChatView(
                            viewModel: multiNoteChatVM(for: conversation)
                        )
                    }
                case .singleNoteChat(let conversationId):
                    if let conversation = viewModel?.singleNoteConversations.first(where: { $0.id == conversationId }),
                       let transcription = conversation.transcription {
                        ChatView(
                            viewModel: singleNoteChatVM(for: conversation, transcription: transcription),
                            embedded: true
                        )
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ChatsListViewModel(modelContext: modelContext)
                }
                consumePendingChatRouteIfNeeded()
            }
            .onChange(of: appState.pendingChatRoute) { _, _ in
                consumePendingChatRouteIfNeeded()
            }
            .onChange(of: navigationPath.count) {
                if navigationPath.isEmpty {
                    viewModel?.loadAll()
                }
            }
            .onChange(of: isSmartSearchEnabled) { _, isEnabled in
                if !isEnabled, selectedTab == .smartSearch {
                    selectedTab = .multiNote
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

    private func consumePendingChatRouteIfNeeded() {
        guard let route = appState.pendingChatRoute else { return }
        if viewModel == nil {
            viewModel = ChatsListViewModel(modelContext: modelContext)
        }
        navigationPath = NavigationPath()
        switch route.kind {
        case .multiNote, .allNotes:
            navigationPath.append(NavigationTarget.multiNoteChat(route.id))
        case .singleNote:
            navigationPath.append(NavigationTarget.singleNoteChat(route.id))
        }
        appState.pendingChatRoute = nil
    }

    // MARK: - ViewModel Caching

    /// Returns a cached (or newly created) ViewModel for the given multi-note conversation.
    /// Prevents repeated Apple FM session initialization on SwiftUI re-renders.
    private func multiNoteChatVM(for conversation: MultiNoteConversation) -> MultiNoteChatViewModel {
        if let cached = cachedMultiNoteVMs[conversation.id] { return cached }
        let vm = MultiNoteChatViewModel(
            conversation: conversation,
            aiService: appState.aiService,
            modelContext: modelContext
        )
        cachedMultiNoteVMs[conversation.id] = vm
        return vm
    }

    private func singleNoteChatVM(for conversation: ChatConversation, transcription: Transcription) -> ChatViewModel {
        if let cached = cachedSingleNoteVMs[conversation.id] { return cached }
        let vm = ChatViewModel(
            conversation: conversation,
            transcription: transcription,
            aiService: appState.aiService,
            modelContext: modelContext
        )
        cachedSingleNoteVMs[conversation.id] = vm
        return vm
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
                            let conversation = viewModel.multiNoteConversations[index]
                            cachedMultiNoteVMs.removeValue(forKey: conversation.id)
                            viewModel.deleteMultiNoteConversation(conversation)
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
                            let conversation = viewModel.singleNoteConversations[index]
                            cachedSingleNoteVMs.removeValue(forKey: conversation.id)
                            viewModel.deleteSingleNoteConversation(conversation)
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

    // MARK: - All Notes Content

    private var allNotesContent: some View {
        Group {
            if let viewModel, !viewModel.allNotesConversations.isEmpty {
                List {
                    ForEach(viewModel.allNotesConversations, id: \.id) { conversation in
                        Button {
                            navigationPath.append(NavigationTarget.multiNoteChat(conversation.id))
                        } label: {
                            multiNoteRow(conversation)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let conversation = viewModel.allNotesConversations[index]
                            cachedMultiNoteVMs.removeValue(forKey: conversation.id)
                            viewModel.deleteMultiNoteConversation(conversation)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Recent Notes Chats",
                    systemImage: "bubble.left.and.bubble.right.fill",
                    description: Text("Start a chat that automatically includes your most recent notes.")
                )
            }
        }
    }

    private func startNewAllNotesChat() {
        guard let viewModel else { return }
        guard let conversation = viewModel.createAllNotesConversation(aiService: appState.aiService) else {
            return
        }
        navigationPath.append(NavigationTarget.multiNoteChat(conversation.id))
    }

    // MARK: - Smart Search Content

    private var smartSearchContent: some View {
        Group {
            if let conversation = viewModel?.smartSearchConversation {
                SmartSearchChatView(viewModel: smartSearchChatVM(for: conversation))
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView {
                        Label("Smart Search", systemImage: "sparkle.magnifyingglass")
                    } description: {
                        Text("Ask questions about all your notes. Relevant notes are found automatically using AI.")
                    }

                    Button {
                        if let conversation = viewModel?.createSmartSearchConversation() {
                            cachedSmartSearchVM = nil
                            _ = smartSearchChatVM(for: conversation)
                        }
                    } label: {
                        Label("Start Smart Search", systemImage: "sparkle.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isAIConfigured)
                }
            }
        }
    }

    private func smartSearchChatVM(for conversation: SmartSearchConversation) -> SmartSearchChatViewModel {
        if let cached = cachedSmartSearchVM, cached.conversation.id == conversation.id { return cached }
        let vm = SmartSearchChatViewModel(
            conversation: conversation,
            aiService: appState.aiService,
            modelContext: modelContext
        )
        cachedSmartSearchVM = vm
        return vm
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
            noteCount: noteCount,
            lastMessage: lastMessage,
            date: conversation.lastInteractionAt
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
            noteCount: nil,
            lastMessage: lastMessage,
            date: conversation.lastInteractionAt
        )
    }
}

// MARK: - Shared Row

private struct ChatRowContent: View {
    let title: String
    let noteCount: Int?
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

            if let noteCount {
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
        .contentShape(.rect)
    }
}
