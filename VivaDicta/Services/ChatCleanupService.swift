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
@MainActor
final class ChatCleanupService {
    static let shared = ChatCleanupService()

    private static let lastCleanupKey = "lastChatCleanupDate"
    private static let cleanupIntervalSeconds: TimeInterval = 24 * 60 * 60

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

        guard isEnabled else {
            logger.logInfo("Chat cleanup: Disabled, skipping")
            return
        }

        let lastCleanup = userDefaults.object(forKey: Self.lastCleanupKey) as? Date
        if let lastCleanup {
            let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanup)
            if timeSinceLastCleanup < minimumCleanupInterval {
                let hoursRemaining = (minimumCleanupInterval - timeSinceLastCleanup) / 3600
                logger.logInfo("Chat cleanup: Skipping, last cleanup was \(Int(timeSinceLastCleanup / 3600))h ago (next in \(Int(hoursRemaining))h)")
                return
            }
        }

        let retentionDays = userDefaults.integer(forKey: UserDefaultsStorage.Keys.chatRetentionDays)
        let effectiveRetentionDays = retentionDays > 0 ? retentionDays : 7

        logger.logInfo("Chat cleanup: Starting with \(effectiveRetentionDays) day retention")

        guard let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -effectiveRetentionDays,
            to: Date()
        ) else {
            logger.logError("Chat cleanup: Failed to calculate cutoff date, aborting")
            return
        }

        let singleSuccess = deleteOldChats(olderThan: cutoffDate, modelContext: modelContext)
        let multiSuccess = deleteOldMultiNoteChats(olderThan: cutoffDate, modelContext: modelContext)

        if singleSuccess && multiSuccess {
            userDefaults.set(Date(), forKey: Self.lastCleanupKey)
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
