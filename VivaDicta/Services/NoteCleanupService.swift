//
//  NoteCleanupService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.07
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData
import os

/// Service responsible for auto-deleting old transcription notes based on user settings
@MainActor
final class NoteCleanupService {
    static let shared = NoteCleanupService()

    private static let lastCleanupKey = "lastNoteCleanupDate"
    private static let cleanupIntervalSeconds: TimeInterval = 24 * 60 * 60 // 24 hours

    private let logger = Logger(category: .app)
    private let userDefaults: UserDefaults
    private let audioDirectory: URL
    private let fileManager: FileManager
    private let minimumCleanupInterval: TimeInterval

    init(
        userDefaults: UserDefaults = UserDefaultsStorage.appPrivate,
        audioDirectory: URL = FileManager.appDirectory(for: .audio),
        fileManager: FileManager = .default,
        minimumCleanupInterval: TimeInterval = cleanupIntervalSeconds
    ) {
        self.userDefaults = userDefaults
        self.audioDirectory = audioDirectory
        self.fileManager = fileManager
        self.minimumCleanupInterval = minimumCleanupInterval
    }

    /// Performs note cleanup based on user settings
    /// - Parameter modelContext: The SwiftData model context to use for queries
    func performCleanupIfNeeded(modelContext: ModelContext) async {
        let isEnabled = userDefaults.bool(forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)

        guard isEnabled else {
            logger.logInfo("Note cleanup: Disabled, skipping")
            return
        }

        // Check if enough time has passed since last cleanup
        let lastCleanup = userDefaults.object(forKey: Self.lastCleanupKey) as? Date
        if let lastCleanup {
            let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanup)
            if timeSinceLastCleanup < minimumCleanupInterval {
                let hoursRemaining = (minimumCleanupInterval - timeSinceLastCleanup) / 3600
                logger.logInfo("Note cleanup: Skipping, last cleanup was \(Int(timeSinceLastCleanup / 3600))h ago (next in \(Int(hoursRemaining))h)")
                return
            }
        }

        // Get retention days (default to 7 if not set)
        let retentionDays = userDefaults.integer(forKey: UserDefaultsStorage.Keys.noteRetentionDays)
        let effectiveRetentionDays = retentionDays > 0 ? retentionDays : 7

        logger.logInfo("Note cleanup: Starting with \(effectiveRetentionDays) day retention")

        guard let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -effectiveRetentionDays,
            to: Date()
        ) else {
            logger.logError("Note cleanup: Failed to calculate cutoff date, aborting")
            return
        }

        let success = await deleteOldNotes(olderThan: cutoffDate, modelContext: modelContext)

        if success {
            userDefaults.set(Date(), forKey: Self.lastCleanupKey)
        }
    }

    /// Deletes transcription notes older than the specified date
    /// - Parameters:
    ///   - cutoffDate: Delete notes before this date
    ///   - modelContext: The SwiftData model context
    /// Returns `true` when cleanup completes successfully (or there is nothing to clean).
    private func deleteOldNotes(olderThan cutoffDate: Date, modelContext: ModelContext) async -> Bool {
        do {
            let predicate = #Predicate<Transcription> { transcription in
                transcription.timestamp < cutoffDate
            }
            let descriptor = FetchDescriptor<Transcription>(predicate: predicate)
            let transcriptions = try modelContext.fetch(descriptor)

            guard !transcriptions.isEmpty else {
                logger.logInfo("Note cleanup: No old notes to clean up")
                return true
            }

            logger.logInfo("Note cleanup: Found \(transcriptions.count) old notes to delete")

            var deletedAudioCount = 0
            var spotlightIDs: [UUID] = []

            for transcription in transcriptions {
                // Delete audio file if exists
                if let audioFileName = transcription.audioFileName {
                    let audioURL = audioDirectory.appending(path: audioFileName)
                    if fileManager.fileExists(atPath: audioURL.path) {
                        do {
                            try fileManager.removeItem(at: audioURL)
                            deletedAudioCount += 1
                        } catch {
                            logger.logError("Note cleanup: Failed to delete audio \(audioFileName): \(error.localizedDescription)")
                        }
                    }
                }

                spotlightIDs.append(transcription.id)
                modelContext.delete(transcription)
            }

            try modelContext.save()
            RecentNotesCache.syncFromDatabase(modelContext: modelContext)

            // Remove from Spotlight index
            if CSSearchableIndex.isIndexingAvailable() && !spotlightIDs.isEmpty {
                do {
                    let index = CSSearchableIndex.default()
                    try await index.deleteAppEntities(identifiedBy: spotlightIDs, ofType: TranscriptionEntity.self)
                } catch {
                    logger.logError("Note cleanup: Failed to remove from Spotlight: \(error.localizedDescription)")
                }
            }

            logger.logInfo("Note cleanup: Deleted \(transcriptions.count) notes, \(deletedAudioCount) audio files")
            return true

        } catch {
            logger.logError("Note cleanup: Failed to fetch transcriptions: \(error.localizedDescription)")
            return false
        }
    }
}
