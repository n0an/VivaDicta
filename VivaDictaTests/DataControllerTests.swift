//
//  DataControllerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.17
//

import Foundation
import SwiftData
import Testing
@testable import VivaDicta

struct DataControllerTests {

    let sut: DataController

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transcription.self, configurations: config)
        sut = DataController(modelContainer: container)
    }

    // MARK: - Helper Methods

    private func createTranscription(
        text: String = "Test transcription",
        enhancedText: String? = nil,
        audioDuration: TimeInterval = 10.0,
        daysAgo: Int = 0
    ) -> Transcription {
        let transcription = Transcription(
            text: text,
            enhancedText: enhancedText,
            audioDuration: audioDuration
        )
        if daysAgo > 0 {
            transcription.timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        }
        return transcription
    }

    // MARK: - Transcriptions Fetching Tests

    @Test func fetchTranscriptions_emptyDatabase_returnsEmptyArray() throws {
        let result = try sut.transcriptions()

        #expect(result.isEmpty)
    }

    @Test func fetchTranscriptions_withData_returnsAllTranscriptions() throws {
        // Insert test data
        let t1 = createTranscription(text: "First note")
        let t2 = createTranscription(text: "Second note")
        sut.modelContext.insert(t1)
        sut.modelContext.insert(t2)
        try sut.modelContext.save()

        let result = try sut.transcriptions()

        #expect(result.count == 2)
    }

    @Test func fetchTranscriptions_sortedByTimestampDescending() throws {
        // Insert with different timestamps
        let older = createTranscription(text: "Older", daysAgo: 2)
        let newer = createTranscription(text: "Newer", daysAgo: 0)
        sut.modelContext.insert(older)
        sut.modelContext.insert(newer)
        try sut.modelContext.save()

        let result = try sut.transcriptions()

        #expect(result.count == 2)
        #expect(result.first?.text == "Newer")
        #expect(result.last?.text == "Older")
    }

    @Test func fetchTranscriptions_withLimit_respectsLimit() throws {
        // Insert multiple transcriptions
        for i in 1...5 {
            let t = createTranscription(text: "Note \(i)")
            sut.modelContext.insert(t)
        }
        try sut.modelContext.save()

        let result = try sut.transcriptions(limit: 3)

        #expect(result.count == 3)
    }

    @Test func fetchTranscriptions_withPredicate_filtersCorrectly() throws {
        let withEnhanced = createTranscription(text: "Original", enhancedText: "Enhanced version")
        let withoutEnhanced = createTranscription(text: "Plain text")
        sut.modelContext.insert(withEnhanced)
        sut.modelContext.insert(withoutEnhanced)
        try sut.modelContext.save()

        let result = try sut.transcriptions(matching: #Predicate {
            $0.enhancedText != nil
        })

        #expect(result.count == 1)
        #expect(result.first?.enhancedText == "Enhanced version")
    }

    // MARK: - Transcription by ID Tests

    @Test func transcriptionById_existingId_returnsTranscription() throws {
        let transcription = createTranscription(text: "Find me")
        sut.modelContext.insert(transcription)
        try sut.modelContext.save()

        let result = try sut.transcription(byId: transcription.id)

        #expect(result != nil)
        #expect(result?.text == "Find me")
    }

    @Test func transcriptionById_nonExistingId_returnsNil() throws {
        let transcription = createTranscription(text: "Exists")
        sut.modelContext.insert(transcription)
        try sut.modelContext.save()

        let nonExistentId = UUID()
        let result = try sut.transcription(byId: nonExistentId)

        #expect(result == nil)
    }

    @Test func transcriptionById_emptyDatabase_returnsNil() throws {
        let result = try sut.transcription(byId: UUID())

        #expect(result == nil)
    }

    // MARK: - Transcription Entities Tests

    @Test func transcriptionEntities_convertsToEntities() throws {
        let transcription = createTranscription(
            text: "Entity test",
            enhancedText: "Enhanced entity",
            audioDuration: 30.0
        )
        sut.modelContext.insert(transcription)
        try sut.modelContext.save()

        let entities = try sut.transcriptionEntities()

        #expect(entities.count == 1)
        let entity = entities.first!
        #expect(entity.id == transcription.id)
        #expect(entity.text == "Entity test")
        #expect(entity.enhancedText == "Enhanced entity")
        #expect(entity.audioDuration == 30.0)
    }

    @Test func transcriptionEntities_withLimit_respectsLimit() throws {
        for i in 1...5 {
            sut.modelContext.insert(createTranscription(text: "Note \(i)"))
        }
        try sut.modelContext.save()

        let entities = try sut.transcriptionEntities(limit: 2)

        #expect(entities.count == 2)
    }

    @Test func transcriptionEntities_withPredicate_filtersCorrectly() throws {
        let longAudio = createTranscription(text: "Long", audioDuration: 120.0)
        let shortAudio = createTranscription(text: "Short", audioDuration: 10.0)
        sut.modelContext.insert(longAudio)
        sut.modelContext.insert(shortAudio)
        try sut.modelContext.save()

        let entities = try sut.transcriptionEntities(matching: #Predicate {
            $0.audioDuration > 60
        })

        #expect(entities.count == 1)
        #expect(entities.first?.text == "Long")
    }

    // MARK: - Transcription Count Tests

    @Test func transcriptionCount_emptyDatabase_returnsZero() throws {
        let count = try sut.transcriptionCount()

        #expect(count == 0)
    }

    @Test func transcriptionCount_withData_returnsCorrectCount() throws {
        sut.modelContext.insert(createTranscription(text: "One"))
        sut.modelContext.insert(createTranscription(text: "Two"))
        sut.modelContext.insert(createTranscription(text: "Three"))
        try sut.modelContext.save()

        let count = try sut.transcriptionCount()

        #expect(count == 3)
    }

    @Test func transcriptionCount_withPredicate_countsFilteredResults() throws {
        // Create transcriptions with different dates
        let recent = createTranscription(text: "Recent", daysAgo: 5)
        let old = createTranscription(text: "Old", daysAgo: 45)
        sut.modelContext.insert(recent)
        sut.modelContext.insert(old)
        try sut.modelContext.save()

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let count = try sut.transcriptionCount(matching: #Predicate {
            $0.timestamp > cutoff
        })

        #expect(count == 1)
    }

    // MARK: - Edge Cases

    @Test func fetchTranscriptions_limitZero_meansNoLimit() throws {
        sut.modelContext.insert(createTranscription(text: "Test"))
        try sut.modelContext.save()

        // In SwiftData, fetchLimit = 0 means no limit (returns all results)
        let result = try sut.transcriptions(limit: 0)

        #expect(result.count == 1)
    }

    @Test func fetchTranscriptions_limitLargerThanData_returnsAllData() throws {
        sut.modelContext.insert(createTranscription(text: "Only one"))
        try sut.modelContext.save()

        let result = try sut.transcriptions(limit: 100)

        #expect(result.count == 1)
    }
}
