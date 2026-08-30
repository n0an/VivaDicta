//
//  AutoDeleteExemptionsTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.08.30
//

import Foundation
import AppGroup
import Testing
import SwiftData
@testable import VivaDicta

@MainActor
@Suite(.tags(.cleanup, .database), .timeLimit(.minutes(1)))
struct AutoDeleteExemptionsTests {

    private let testSuiteName = "AutoDeleteExemptionsTests.\(UUID().uuidString)"

    private func makeTestDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.removePersistentDomain(forName: testSuiteName)
        return defaults
    }

    private func makeTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoDeleteExemptionsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func createAudioFile(named fileName: String, in directory: URL) throws {
        let fileURL = directory.appendingPathComponent(fileName)
        try Data("test audio data".utf8).write(to: fileURL)
    }

    @discardableResult
    private func createTranscription(
        text: String,
        audioFileName: String? = nil,
        daysAgo: Int,
        tags: [TranscriptionTag] = [],
        in context: ModelContext
    ) -> Transcription {
        let transcription = Transcription(
            text: text,
            audioDuration: 10.0,
            audioFileName: audioFileName
        )
        transcription.timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        context.insert(transcription)

        for tag in tags {
            let assignment = TranscriptionTagAssignment(tagId: tag.id, transcription: transcription)
            context.insert(assignment)
        }
        return transcription
    }

    @discardableResult
    private func createTag(
        name: String,
        isExcludedFromAutoDelete: Bool,
        in context: ModelContext
    ) -> TranscriptionTag {
        let tag = TranscriptionTag(name: name, isExcludedFromAutoDelete: isExcludedFromAutoDelete)
        context.insert(tag)
        return tag
    }

    // MARK: - Resolver

    @Test func resolverIsEmptyWhenNoTagIsProtected() throws {
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext
        createTag(name: "Work", isExcludedFromAutoDelete: false, in: context)
        try context.save()

        let sut = AutoDeleteExemptions(modelContext: context)

        #expect(sut.isEmpty)
    }

    @Test func resolverCollectsOnlyProtectedTags() throws {
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext
        let important = createTag(name: "Important", isExcludedFromAutoDelete: true, in: context)
        createTag(name: "Scratch", isExcludedFromAutoDelete: false, in: context)
        try context.save()

        let sut = AutoDeleteExemptions(modelContext: context)

        #expect(sut.protectedTagIDs == [important.id])
    }

    @Test func noteWithProtectedTagIsExempt() throws {
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext
        let important = createTag(name: "Important", isExcludedFromAutoDelete: true, in: context)
        let scratch = createTag(name: "Scratch", isExcludedFromAutoDelete: false, in: context)
        let kept = createTranscription(text: "Kept", daysAgo: 30, tags: [important], in: context)
        let dropped = createTranscription(text: "Dropped", daysAgo: 30, tags: [scratch], in: context)
        let untagged = createTranscription(text: "Untagged", daysAgo: 30, in: context)
        try context.save()

        let sut = AutoDeleteExemptions(modelContext: context)

        #expect(sut.isExempt(kept))
        #expect(sut.isExempt(dropped) == false)
        #expect(sut.isExempt(untagged) == false)
    }

    @Test func partitionSplitsProtectedFromDeletable() throws {
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext
        let important = createTag(name: "Important", isExcludedFromAutoDelete: true, in: context)
        let kept = createTranscription(text: "Kept", daysAgo: 30, tags: [important], in: context)
        let dropped = createTranscription(text: "Dropped", daysAgo: 30, in: context)
        try context.save()

        let sut = AutoDeleteExemptions(modelContext: context)
        let (deletable, exempt) = sut.partition([kept, dropped])

        #expect(deletable.map(\.text) == ["Dropped"])
        #expect(exempt.map(\.text) == ["Kept"])
    }

    @Test func partitionPassesEverythingThroughWhenNothingIsProtected() throws {
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext
        let first = createTranscription(text: "First", daysAgo: 30, in: context)
        let second = createTranscription(text: "Second", daysAgo: 30, in: context)
        try context.save()

        let sut = AutoDeleteExemptions(modelContext: context)
        let (deletable, exempt) = sut.partition([first, second])

        #expect(deletable.count == 2)
        #expect(exempt.isEmpty)
    }

    // MARK: - Note cleanup

    @Test func noteCleanupKeepsNotesWithProtectedTag() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        let keptFileName = "kept-audio.m4a"
        let droppedFileName = "dropped-audio.m4a"
        try createAudioFile(named: keptFileName, in: audioDir)
        try createAudioFile(named: droppedFileName, in: audioDir)

        let important = createTag(name: "Important", isExcludedFromAutoDelete: true, in: context)
        createTranscription(text: "Kept", audioFileName: keptFileName, daysAgo: 30, tags: [important], in: context)
        createTranscription(text: "Dropped", audioFileName: droppedFileName, daysAgo: 30, in: context)
        try context.save()

        let sut = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await sut.performCleanupIfNeeded(modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<Transcription>())
        #expect(remaining.map(\.text) == ["Kept"])
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(keptFileName).path))
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(droppedFileName).path) == false)

        try? FileManager.default.removeItem(at: audioDir)
    }

    @Test func noteCleanupStillDeletesWhenTagIsNotProtected() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoNoteCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.noteRetentionDays)

        let scratch = createTag(name: "Scratch", isExcludedFromAutoDelete: false, in: context)
        createTranscription(text: "Dropped", daysAgo: 30, tags: [scratch], in: context)
        try context.save()

        let sut = NoteCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await sut.performCleanupIfNeeded(modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<Transcription>())
        #expect(remaining.isEmpty)

        try? FileManager.default.removeItem(at: audioDir)
    }

    // MARK: - Audio cleanup

    @Test func audioCleanupKeepsAudioForNotesWithProtectedTag() async throws {
        let defaults = makeTestDefaults()
        let audioDir = try makeTestDirectory()
        let container = try TestModelContainer.makeInMemory()
        let context = container.mainContext

        defaults.set(true, forKey: UserDefaultsStorage.Keys.isAutoAudioCleanupEnabled)
        defaults.set(7, forKey: UserDefaultsStorage.Keys.audioRetentionDays)

        let keptFileName = "kept-audio.m4a"
        let droppedFileName = "dropped-audio.m4a"
        try createAudioFile(named: keptFileName, in: audioDir)
        try createAudioFile(named: droppedFileName, in: audioDir)

        let important = createTag(name: "Important", isExcludedFromAutoDelete: true, in: context)
        let kept = createTranscription(text: "Kept", audioFileName: keptFileName, daysAgo: 30, tags: [important], in: context)
        let dropped = createTranscription(text: "Dropped", audioFileName: droppedFileName, daysAgo: 30, in: context)
        try context.save()

        let sut = AudioCleanupService(
            userDefaults: defaults,
            audioDirectory: audioDir,
            minimumCleanupInterval: 0
        )
        await sut.performCleanupIfNeeded(modelContext: context)

        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(keptFileName).path))
        #expect(FileManager.default.fileExists(atPath: audioDir.appendingPathComponent(droppedFileName).path) == false)
        #expect(kept.audioFileName == keptFileName)
        #expect(dropped.audioFileName == nil)

        try? FileManager.default.removeItem(at: audioDir)
    }
}
