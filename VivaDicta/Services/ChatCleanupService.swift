//
//  ChatCleanupService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import SwiftData
import os

/// Service responsible for auto-deleting old chat conversations based on user settings.
///
/// Deleting a `ChatConversation` cascade-deletes its `ChatMessage` records.
/// Detached single-note chats are also cleaned up conservatively to prevent hidden orphan buildup.
@MainActor
final class ChatCleanupService {
    static let shared = ChatCleanupService()

    private static let lastCleanupKey = "lastChatCleanupDate"
    private static let cleanupIntervalSeconds: TimeInterval = 24 * 60 * 60
    private static let orphanGracePeriodDays = 3

    private let logger = Logger(category: .app)
    private let userDefaults: UserDefaults
    private let minimumCleanupInterval: TimeInterval

    init(
        userDefaults: UserDefaults = UserDefaultsStorage.appPrivate,
        minimumCleanupInterval: TimeInterval = cleanupIntervalSeconds
    ) {
        self.userDefaults = userDefaults
        self.minimumCleanupInterval = minimumCleanupInterval
    }

    func performCleanupIfNeeded(modelContext: ModelContext) async {
        let isEnabled = userDefaults.bool(forKey: UserDefaultsStorage.Keys.isAutoChatCleanupEnabled)

        let lastCleanup = userDefaults.object(forKey: Self.lastCleanupKey) as? Date
        if let lastCleanup {
            let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanup)
            if timeSinceLastCleanup < minimumCleanupInterval {
                let hoursRemaining = (minimumCleanupInterval - timeSinceLastCleanup) / 3600
                logger.logInfo("Chat cleanup: Skipping, last cleanup was \(Int(timeSinceLastCleanup / 3600))h ago (next in \(Int(hoursRemaining))h)")
                return
            }
        }

        guard let orphanCutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.orphanGracePeriodDays,
            to: Date()
        ) else {
            logger.logError("Chat cleanup: Failed to calculate orphan cutoff date, aborting")
            return
        }

        let orphanSuccess = deleteOrphanedSingleNoteChats(olderThan: orphanCutoffDate, modelContext: modelContext)

        guard isEnabled else {
            if orphanSuccess {
                userDefaults.set(Date(), forKey: Self.lastCleanupKey)
            }
            logger.logInfo("Chat cleanup: Auto-delete disabled, skipped retention cleanup")
            return
        }

        let retentionDays = userDefaults.integer(forKey: UserDefaultsStorage.Keys.chatRetentionDays)
        let effectiveRetentionDays = retentionDays > 0 ? retentionDays : 7

        logger.logInfo("Chat cleanup: Starting with \(effectiveRetentionDays) day retention")

        guard let retentionCutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -effectiveRetentionDays,
            to: Date()
        ) else {
            logger.logError("Chat cleanup: Failed to calculate retention cutoff date, aborting")
            return
        }

        let singleSuccess = deleteOldChats(olderThan: retentionCutoffDate, modelContext: modelContext)
        let multiSuccess = deleteOldMultiNoteChats(olderThan: retentionCutoffDate, modelContext: modelContext)

        if orphanSuccess && singleSuccess && multiSuccess {
            userDefaults.set(Date(), forKey: Self.lastCleanupKey)
        }
    }

    private func deleteOrphanedSingleNoteChats(olderThan cutoffDate: Date, modelContext: ModelContext) -> Bool {
        do {
            let predicate = #Predicate<ChatConversation> { conversation in
                conversation.lastInteractionAt < cutoffDate
            }
            let descriptor = FetchDescriptor<ChatConversation>(predicate: predicate)
            let orphanedConversations = try modelContext.fetch(descriptor).filter { $0.transcription == nil }

            guard !orphanedConversations.isEmpty else {
                logger.logInfo("Chat cleanup: No orphaned single-note chats to clean up")
                return true
            }

            logger.logInfo("Chat cleanup: Found \(orphanedConversations.count) orphaned single-note chats to delete")

            for conversation in orphanedConversations {
                modelContext.delete(conversation)
            }

            try modelContext.save()

            logger.logInfo("Chat cleanup: Deleted \(orphanedConversations.count) orphaned single-note chats")
            return true

        } catch {
            logger.logError("Chat cleanup: Failed orphan cleanup: \(error.localizedDescription)")
            return false
        }
    }

    private func deleteOldChats(olderThan cutoffDate: Date, modelContext: ModelContext) -> Bool {
        do {
            let predicate = #Predicate<ChatConversation> { conversation in
                conversation.createdAt < cutoffDate
            }
            let descriptor = FetchDescriptor<ChatConversation>(predicate: predicate)
            let conversations = try modelContext.fetch(descriptor)

            guard !conversations.isEmpty else {
                logger.logInfo("Chat cleanup: No old chats to clean up")
                return true
            }

            logger.logInfo("Chat cleanup: Found \(conversations.count) old chats to delete")

            for conversation in conversations {
                modelContext.delete(conversation)
            }

            try modelContext.save()

            logger.logInfo("Chat cleanup: Deleted \(conversations.count) conversations")
            return true

        } catch {
            logger.logError("Chat cleanup: Failed: \(error.localizedDescription)")
            return false
        }
    }

    private func deleteOldMultiNoteChats(olderThan cutoffDate: Date, modelContext: ModelContext) -> Bool {
        do {
            let predicate = #Predicate<MultiNoteConversation> { conversation in
                conversation.createdAt < cutoffDate
            }
            let descriptor = FetchDescriptor<MultiNoteConversation>(predicate: predicate)
            let conversations = try modelContext.fetch(descriptor)

            guard !conversations.isEmpty else {
                logger.logInfo("Multi-note chat cleanup: No old chats to clean up")
                return true
            }

            logger.logInfo("Multi-note chat cleanup: Found \(conversations.count) old chats to delete")

            for conversation in conversations {
                modelContext.delete(conversation)
            }

            try modelContext.save()

            logger.logInfo("Multi-note chat cleanup: Deleted \(conversations.count) conversations")
            return true

        } catch {
            logger.logError("Multi-note chat cleanup: Failed: \(error.localizedDescription)")
            return false
        }
    }
}
