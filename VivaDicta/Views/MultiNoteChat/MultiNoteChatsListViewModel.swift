//
//  MultiNoteChatsListViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import SwiftData

/// View model for the chats list screen (both multi-note and single-note).
@Observable
@MainActor
final class ChatsListViewModel {
    var multiNoteConversations: [MultiNoteConversation] = []
    var singleNoteConversations: [ChatConversation] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAll()
    }

    func loadAll() {
        loadMultiNote()
        loadSingleNote()
    }

    func loadMultiNote() {
        let descriptor = FetchDescriptor<MultiNoteConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        multiNoteConversations = (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadSingleNote() {
        let descriptor = FetchDescriptor<ChatConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        // Only show conversations that have messages
        singleNoteConversations = all.filter { !($0.messages ?? []).isEmpty }
    }

    func deleteMultiNoteConversation(_ conversation: MultiNoteConversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
        loadMultiNote()
    }

    func deleteSingleNoteConversation(_ conversation: ChatConversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
        loadSingleNote()
    }
}
