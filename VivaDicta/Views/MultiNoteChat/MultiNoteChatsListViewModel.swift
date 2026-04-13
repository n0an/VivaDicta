//
//  MultiNoteChatsListViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import SwiftData

/// View model for the chats list screen (multi-note, single-note, and smart search).
@Observable
@MainActor
final class ChatsListViewModel {
    var multiNoteConversations: [MultiNoteConversation] = []
    var singleNoteConversations: [ChatConversation] = []
    var smartSearchConversation: SmartSearchConversation?
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAll()
    }

    func loadAll() {
        loadMultiNote()
        loadSingleNote()
        loadSmartSearch()
    }

    func loadMultiNote() {
        let descriptor = FetchDescriptor<MultiNoteConversation>(
            sortBy: [SortDescriptor(\.lastInteractionAt, order: .reverse)]
        )
        multiNoteConversations = (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadSingleNote() {
        let descriptor = FetchDescriptor<ChatConversation>(
            sortBy: [SortDescriptor(\.lastInteractionAt, order: .reverse)]
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

    // MARK: - Smart Search

    func loadSmartSearch() {
        let descriptor = FetchDescriptor<SmartSearchConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        smartSearchConversation = (try? modelContext.fetch(descriptor))?.first
    }

    func createSmartSearchConversation() -> SmartSearchConversation {
        let conversation = SmartSearchConversation()
        modelContext.insert(conversation)
        try? modelContext.save()
        smartSearchConversation = conversation
        return conversation
    }

    func deleteSmartSearchConversation() {
        guard let conversation = smartSearchConversation else { return }
        modelContext.delete(conversation)
        try? modelContext.save()
        smartSearchConversation = nil
    }
}
