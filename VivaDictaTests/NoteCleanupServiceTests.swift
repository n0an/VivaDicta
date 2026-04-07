//
//  NoteCleanupServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.04.07
//

import Foundation
import Testing
import SwiftData
@testable import VivaDicta

@MainActor
struct NoteCleanupServiceTests {

    private let testSuiteName = "NoteCleanupServiceTests"

    private func makeTestDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.removePersistentDomain(forName: testSuiteName)
        return defaults
    }

    private func makeTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoteCleanupTests-\(UUID().uuidString)")
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

        defaults.set(false, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)

        let fileName = "old-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            audioFileName: fileName,
            daysAgo: 30,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Transcription and audio should still exist
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.count == 1)
        #expect(remaining.first?.audioFileName == fileName)

        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Retention Period Tests

    @Test func cleanupWithDefaultRetentionDays() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)

        let oldFileName = "old-audio.m4a"
        let recentFileName = "recent-audio.m4a"
        try createAudioFile(named: oldFileName, in: audioDir)
        try createAudioFile(named: recentFileName, in: audioDir)

        _ = createTranscription(
            text: "Old transcription",
            audioFileName: oldFileName,
            daysAgo: 10,
            in: context
        )
        _ = createTranscription(
            text: "Recent transcription",
            audioFileName: recentFileName,
            daysAgo: 3,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Old note fully deleted, recent note kept
        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(oldFileName).path))
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(recentFileName).path))

        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.count == 1)
        #expect(remaining.first?.text == "Recent transcription")

        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupWithCustomRetentionDays() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(3, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        let fileName = "audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        _ = createTranscription(
            audioFileName: fileName,
            daysAgo: 5,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.isEmpty)

        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Full Deletion Tests

    @Test func transcriptionFullyDeletedNotJustAudio() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        let fileName = "test-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        let transcription = createTranscription(
            text: "This should be fully deleted",
            audioFileName: fileName,
            daysAgo: 10,
            in: context
        )
        transcription.enhancedText = "Enhanced version"
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Both audio file and transcription record should be gone
        #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.isEmpty)

        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func noteWithoutAudioAlsoDeleted() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        _ = createTranscription(
            text: "Old note without audio",
            audioFileName: nil,
            daysAgo: 30,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.isEmpty)

        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - No Matching Notes Tests

    @Test func cleanupWithNoOldNotes() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        let fileName = "recent-audio.m4a"
        try createAudioFile(named: fileName, in: audioDir)
        _ = createTranscription(
            audioFileName: fileName,
            daysAgo: 1,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(fileName).path))
        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.count == 1)

        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Multiple Notes Tests

    @Test func cleanupMultipleOldNotes() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        for i in 1...5 {
            let fileName = "audio-\(i).m4a"
            try createAudioFile(named: fileName, in: audioDir)
            _ = createTranscription(
                text: "Transcription \(i)",
                audioFileName: fileName,
                daysAgo: 10 + i,
                in: context
            )
        }
        // One recent note that should survive
        let recentFileName = "recent.m4a"
        try createAudioFile(named: recentFileName, in: audioDir)
        _ = createTranscription(
            text: "Recent note",
            audioFileName: recentFileName,
            daysAgo: 1,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // 5 old notes deleted, 1 recent survives
        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.count == 1)
        #expect(remaining.first?.text == "Recent note")

        for i in 1...5 {
            #expect(!FileManager.default.fileExists(atPath: audioDir.appendingPathComponent("audio-\(i).m4a").path))
        }
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(recentFileName).path))

        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Throttling Tests

    @Test func cleanupSkippedWhenRunRecently() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        let oneHourAgo = Date().addingTimeInterval(-3600)
        defaults.set(oneHourAgo, forKey: "lastNoteCleanupDate")

        _ = createTranscription(
            text: "Old note",
            daysAgo: 10,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 24 * 60 * 60
        )
        await service.performCleanupIfNeeded(modelContext: context)

        // Note should NOT be deleted because cleanup ran recently
        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.count == 1)

        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupRunsOnFirstLaunch() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        _ = createTranscription(
            text: "Old note",
            daysAgo: 10,
            in: context
        )
        try context.save()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 24 * 60 * 60
        )
        await service.performCleanupIfNeeded(modelContext: context)

        let fetchDescriptor = FetchDescriptor<Transcription>()
        let remaining = try context.fetch(fetchDescriptor)
        #expect(remaining.isEmpty)

        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func cleanupUpdatesLastCleanupTimestamp() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try makeModelContainer()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        #expect(defaults.object(forKey: "lastNoteCleanupDate") == nil)

        _ = createTranscription(daysAgo: 10, in: context)
        try context.save()

        let beforeCleanup = Date()

        let service = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await service.performCleanupIfNeeded(modelContext: context)

        let lastCleanup = defaults.object(forKey: "lastNoteCleanupDate") as? Date
        #expect(lastCleanup != nil)
        #expect(lastCleanup! >= beforeCleanup)

        try? FileManager.default.removeItem(at: audioDir)
    }
}
