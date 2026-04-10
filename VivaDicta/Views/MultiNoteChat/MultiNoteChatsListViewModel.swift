//
//  MultiNoteChatsListViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import SwiftData

/// View model for the multi-note chats list screen.
@Observable
@MainActor
final class MultiNoteChatsListViewModel {
    var conversations: [MultiNoteConversation] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadConversations()
    }

    func loadConversations() {
        let descriptor = FetchDescriptor<MultiNoteConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        conversations = (try? modelContext.fetch(descriptor)) ?? []
    }

    func deleteConversation(_ conversation: MultiNoteConversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
        loadConversations()
    }
}
