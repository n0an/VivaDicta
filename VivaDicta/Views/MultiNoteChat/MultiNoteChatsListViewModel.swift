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
    /// User-picked multi-note conversations (isAllNotes == false).
    var multiNoteConversations: [MultiNoteConversation] = []
    /// Conversations created from the "All Notes" shortcut (isAllNotes == true).
    var allNotesConversations: [MultiNoteConversation] = []
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
        let all = (try? modelContext.fetch(descriptor)) ?? []
        multiNoteConversations = all.filter { !$0.isAllNotes }
        allNotesConversations = all.filter { $0.isAllNotes }
    }

    func loadSingleNote() {
        let descriptor = FetchDescriptor<ChatConversation>(
            sortBy: [SortDescriptor(\.lastInteractionAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        // Hide detached conversations so sync-edge or legacy orphan rows do not surface as "Deleted Note".
        singleNoteConversations = all.filter { conversation in
            guard conversation.transcription != nil else { return false }
            return !(conversation.messages ?? []).isEmpty
        }
    }

    func deleteMultiNoteConversation(_ conversation: MultiNoteConversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
        loadMultiNote()
    }

    /// Creates an "All Notes" conversation pre-populated with the most recent
    /// notes that fit the current provider/model budget.
    ///
    /// Returns nil if the user has no notes yet.
    func createAllNotesConversation(
        aiService: AIService,
        targetCount: Int = MultiNoteContextManager.allNotesDefaultTargetCount
    ) -> MultiNoteConversation? {
        let provider = aiService.selectedMode.aiProvider ?? .apple
        let model = aiService.selectedMode.aiModel

        var fetchDescriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = targetCount
        let recentNotes = (try? modelContext.fetch(fetchDescriptor)) ?? []

        guard !recentNotes.isEmpty else { return nil }

        let selected = MultiNoteContextManager.selectRecentNotesForAllNotesPack(
            from: recentNotes,
            provider: provider,
            model: model,
            targetCount: targetCount
        )
        guard !selected.isEmpty else { return nil }

        let totalCount = (try? modelContext.fetchCount(FetchDescriptor<Transcription>())) ?? selected.count

        let conversation = MultiNoteConversation()
        conversation.isAllNotes = true
        conversation.title = selected.count == totalCount
            ? "Recent Notes (\(selected.count))"
            : "Recent Notes - \(selected.count) of \(totalCount)"
        conversation.noteContext = MultiNoteContextManager.assembleNoteText(from: selected)
        conversation.sourceNoteCount = selected.count
        conversation.transcriptions = selected
        modelContext.insert(conversation)
        try? modelContext.save()

        loadMultiNote()
        return conversation
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
