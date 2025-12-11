//
//  AudioCleanupService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.11
//

import Foundation
import SwiftData
import os

/// Service responsible for cleaning up old audio files based on user settings
@MainActor
final class AudioCleanupService {
    static let shared = AudioCleanupService()

    private static let lastCleanupKey = "lastAudioCleanupDate"
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

    /// Performs audio cleanup based on user settings
    /// - Parameter modelContext: The SwiftData model context to use for queries
    func performCleanupIfNeeded(modelContext: ModelContext) async {
        // Check if auto cleanup is enabled
        let isEnabled = userDefaults.bool(forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)

        guard isEnabled else {
            logger.logInfo("Audio cleanup: Disabled, skipping")
            return
        }

        // Check if enough time has passed since last cleanup
        let lastCleanup = userDefaults.object(forKey: Self.lastCleanupKey) as? Date
        if let lastCleanup = lastCleanup {
            let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanup)
            if timeSinceLastCleanup < minimumCleanupInterval {
                let hoursRemaining = (minimumCleanupInterval - timeSinceLastCleanup) / 3600
                logger.logInfo("Audio cleanup: Skipping, last cleanup was \(Int(timeSinceLastCleanup / 3600))h ago (next in \(Int(hoursRemaining))h)")
                return
            }
        }

        // Get retention days (default to 7 if not set)
        let retentionDays = userDefaults.integer(forKey: UserDefaultsStorage.Keys.audioRetentionDays)
        let effectiveRetentionDays = retentionDays > 0 ? retentionDays : 7

        logger.logInfo("Audio cleanup: Starting with \(effectiveRetentionDays) day retention")

        // Calculate cutoff date
        guard let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -effectiveRetentionDays,
            to: Date()
        ) else {
            logger.logError("Audio cleanup: Failed to calculate cutoff date, aborting")
            return
        }

        await cleanupAudioFiles(olderThan: cutoffDate, modelContext: modelContext)

        // Update last cleanup timestamp
        userDefaults.set(Date(), forKey: Self.lastCleanupKey)
    }

    /// Deletes audio files for transcriptions older than the specified date
    /// - Parameters:
    ///   - cutoffDate: Delete audio files for transcriptions before this date
    ///   - modelContext: The SwiftData model context
    private func cleanupAudioFiles(olderThan cutoffDate: Date, modelContext: ModelContext) async {
        do {
            // Fetch transcriptions older than cutoff date that have audio files
            let predicate = #Predicate<Transcription> { transcription in
                transcription.timestamp < cutoffDate && transcription.audioFileName != nil
            }
            let descriptor = FetchDescriptor<Transcription>(predicate: predicate)
            let transcriptions = try modelContext.fetch(descriptor)
            
            guard !transcriptions.isEmpty else {
                logger.logInfo("Audio cleanup: No old audio files to clean up")
                return
            }
            
            logger.logInfo("Audio cleanup: Found \(transcriptions.count) transcriptions with old audio files")

            var deletedCount = 0

            for transcription in transcriptions {
                guard let audioFileName = transcription.audioFileName else { continue }

                let audioURL = audioDirectory.appendingPathComponent(audioFileName)

                // Delete the file
                if fileManager.fileExists(atPath: audioURL.path) {
                    do {
                        try fileManager.removeItem(at: audioURL)
                        deletedCount += 1
                    } catch {
                        logger.logError("Audio cleanup: Failed to delete \(audioFileName): \(error.localizedDescription)")
                    }
                }

                // Clear the audio file reference in the transcription
                transcription.audioFileName = nil
            }

            // Save changes
            try modelContext.save()

            logger.logInfo("Audio cleanup: Deleted \(deletedCount) files")

        } catch {
            logger.logError("Audio cleanup: Failed to fetch transcriptions: \(error.localizedDescription)")
        }
    }
}
