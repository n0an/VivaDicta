//
//  AudioCleanupServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.11
//

import Foundation
import Testing
import SwiftData
@testable import VivaDicta

@MainActor
struct AudioCleanupServiceTests {

    private let testSuiteName = "AudioCleanupServiceTests"

    private func makeTestDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.removePersistentDomain(forName: testSuiteName)
        return defaults
    }

    private func makeTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioCleanupTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func makeModelContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Transcription.self, configurations: config)
    }

    private func createTranscription(
        text: String = "Test transcription",
        audioFileName: String? = nil,
        daysAgo: Int = 0,
        in context: ModelContext
    ) -> Transcription {
        let transcription = Transcription(
            text: text,
            audioDuration: 10.0,
            audioFileName: audioFileName
        )
        // Set timestamp to specified days ago
        if daysAgo > 0 {
            transcription.timestamp = Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: Date()
            ) ?? Date()
        }
        context.insert(transcription)
        return transcription
    }

    private func createAudioFile(named fileName: String, in directory: URL) throws {
        let fileURL = directory.appendingPathComponent(fileName)
        let testData = "test audio data".data(using: .utf8)!
        try testData.write(to: fileURL)
    }

    // MARK: - Cleanup Disabled Tests

    @Test func cleanupSkippedWhenDisabled() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup: cleanup disabled (default is false)
        defaults.set(false, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)

        // Create old transcription with audio
        let fileName = "old-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 30,
            in: context
        )
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: audio file still exists, transcription unchanged
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == fileName)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Retention Period Tests

    @Test func cleanupWithDefaultRetentionDays() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup: cleanup enabled, retention days not set (should default to 7)
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        // Don't set audioRetentionDays - should default to 7

        // Create transcriptions of various ages
        let oldFileName = "old-audio.m4a"
        let recentFileName = "recent-audio.m4a"
        try createAudioFile(named: oldFileName, in: audioDir)
        try createAudioFile(named: recentFileName, in: audioDir)

        let oldTranscription = createTranscription(
            text: "Old transcription",
            audioFileName: oldFileName,
            daysAgo: 10,
            in: context
        )
        let recentTranscription = createTranscription(
            text: "Recent transcription",
            audioFileName: recentFileName,
            daysAgo: 3,
            in: context
        )
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: old file deleted, recent file kept
        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(oldFileName).path))
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(recentFileName).path))
        #expect(oldTranscription.audioFileName == nil)
        #expect(recentTranscription.audioFileName == recentFileName)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupWithCustomRetentionDays() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup: cleanup enabled with 3 day retention
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(3, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Create transcription 5 days old (should be deleted with 3 day retention)
        let fileName = "audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 5,
            in: context
        )
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: file deleted
        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupWithZeroRetentionDays_defaultsToSeven() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup: cleanup enabled with 0 retention (should default to 7)
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(0, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Create transcription 5 days old (should NOT be deleted with default 7 day retention)
        let fileName = "audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 5,
            in: context
        )
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: file still exists (5 days < 7 day default retention)
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == fileName)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Audio File Name Cleared Tests

    @Test func audioFileNameClearedAfterCleanup() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        let fileName = "test-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        try context.save()

        #expect(transcription.audioFileName == fileName)

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: audioFileName is cleared
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Transcription Text Preserved Tests

    @Test func transcriptionTextPreservedAfterCleanup() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        let originalText = "This is the original transcription text that should be preserved"
        let enhancedText = "This is enhanced text"
        let fileName = "test-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)

        let transcription = createTranscription(
            text: originalText,
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        transcription.enhancedText = enhancedText
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: text preserved, audio cleared
        #expect(transcription.text == originalText)
        #expect(transcription.enhancedText == enhancedText)
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - No Matching Transcriptions Tests

    @Test func cleanupWithNoOldTranscriptions() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Create only recent transcriptions
        let fileName = "recent-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 1,
            in: context
        )
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: nothing changed
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == fileName)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupWithNoAudioFiles() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Create old transcription WITHOUT audio
        let transcription = createTranscription(
            text: "Old transcription without audio",
            audioFileName: nil,
            daysAgo: 30,
            in: context
        )
        try context.save()

        // Run cleanup - should complete without errors
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: transcription unchanged
        #expect(transcription.text == "Old transcription without audio")
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - File Deletion Tests

    @Test func fileActuallyDeletedFromDisk() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        let fileName = "to-delete.m4a"
        let filePath = audioDir.appendingPathComponent(fileName)
        try createAudioFile(named: fileName, in: audioDir)

        // Verify file exists before cleanup
        #expect(FileManager.default.fileExists(atPath: filePath.path))

        _ = createTranscription(
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify file deleted from disk
        #expect(!FileManager.default.fileExists(atPath: filePath.path))

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupHandlesMissingAudioFile() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Create transcription with audioFileName but NO actual file on disk
        let transcription = createTranscription(
            audioFileName: "nonexistent-file.m4a",
            daysAgo: 10,
            in: context
        )
        try context.save()

        // Run cleanup - should complete without errors
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: audioFileName still cleared even if file didn't exist
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Multiple Transcriptions Tests

    @Test func cleanupMultipleOldTranscriptions() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Create multiple old transcriptions
        var transcriptions: [Transcription] = []
        for i in 1...5 {
            let fileName = "audio-\(i).m4a"
            try createAudioFile(named: fileName, in: audioDir)
            let t = createTranscription(
                text: "Transcription \(i)",
                audioFileName: fileName,
                daysAgo: 10 + i,
                in: context
            )
            transcriptions.append(t)
        }
        try context.save()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: all files deleted, all audioFileNames cleared
        for (i, transcription) in transcriptions.enumerated() {
            let fileName = "audio-\(i + 1).m4a"
            #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
            #expect(transcription.audioFileName == nil)
            #expect(transcription.text == "Transcription \(i + 1)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Throttling Tests

    @Test func cleanupSkippedWhenRunRecently() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Set last cleanup to 1 hour ago
        let oneHourAgo = Date().addingTimeInterval(-3600)
        defaults.set(oneHourAgo, forKey: "lastAudioCleanupDate")

        let fileName = "old-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        try context.save()

        // Run cleanup with 24 hour interval (default)
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 24 * 60 * 60
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: file NOT deleted because cleanup ran recently
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == fileName)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupRunsWhenIntervalPassed() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Set last cleanup to 25 hours ago
        let twentyFiveHoursAgo = Date().addingTimeInterval(-25 * 3600)
        defaults.set(twentyFiveHoursAgo, forKey: "lastAudioCleanupDate")

        let fileName = "old-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        try context.save()

        // Run cleanup with 24 hour interval
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 24 * 60 * 60
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: file deleted because enough time passed
        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupRunsOnFirstLaunch() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup - no lastCleanupDate set (first launch)
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        let fileName = "old-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        try context.save()

        // Run cleanup with 24 hour interval
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 24 * 60 * 60
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify: file deleted on first launch
        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        #expect(transcription.audioFileName == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupUpdatesLastCleanupTimestamp() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        // Setup
        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        // Verify no timestamp initially
        #expect(defaults.object(forKey: "lastAudioCleanupDate") == nil)

        let fileName = "old-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        _ = createTranscription(
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        try context.save()

        let beforeCleanup = Date()

        // Run cleanup
        let service = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Verify timestamp was set
        let lastCleanup = defaults.object(forKey: "lastAudioCleanupDate") as? Date
        #expect(lastCleanup != nil)
        #expect(lastCleanup! >= beforeCleanup)

        // Cleanup
        try? FileManager.default.removeItem(at: audioDir)
    }
}
