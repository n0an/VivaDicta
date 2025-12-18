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

    // MARK: - Helper Methods

    private func makeDataController() -> DataController {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transcription.self, configurations: config)
        return DataController(modelContainer: container)
    }

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
        let controller = makeDataController()

        let result = try controller.transcriptions()

        #expect(result.isEmpty)
    }

    @Test func fetchTranscriptions_withData_returnsAllTranscriptions() throws {
        let controller = makeDataController()

        // Insert test data
        let t1 = createTranscription(text: "First note")
        let t2 = createTranscription(text: "Second note")
        controller.modelContext.insert(t1)
        controller.modelContext.insert(t2)
        try controller.modelContext.save()

        let result = try controller.transcriptions()

        #expect(result.count == 2)
    }

    @Test func fetchTranscriptions_sortedByTimestampDescending() throws {
        let controller = makeDataController()

        // Insert with different timestamps
        let older = createTranscription(text: "Older", daysAgo: 2)
        let newer = createTranscription(text: "Newer", daysAgo: 0)
        controller.modelContext.insert(older)
        controller.modelContext.insert(newer)
        try controller.modelContext.save()

        let result = try controller.transcriptions()

        #expect(result.count == 2)
        #expect(result.first?.text == "Newer")
        #expect(result.last?.text == "Older")
    }

    @Test func fetchTranscriptions_withLimit_respectsLimit() throws {
        let controller = makeDataController()

        // Insert multiple transcriptions
        for i in 1...5 {
            let t = createTranscription(text: "Note \(i)")
            controller.modelContext.insert(t)
        }
        try controller.modelContext.save()

        let result = try controller.transcriptions(limit: 3)

        #expect(result.count == 3)
    }

    @Test func fetchTranscriptions_withPredicate_filtersCorrectly() throws {
        let controller = makeDataController()

        let withEnhanced = createTranscription(text: "Original", enhancedText: "Enhanced version")
        let withoutEnhanced = createTranscription(text: "Plain text")
        controller.modelContext.insert(withEnhanced)
        controller.modelContext.insert(withoutEnhanced)
        try controller.modelContext.save()

        let result = try controller.transcriptions(matching: #Predicate {
            $0.enhancedText != nil
        })

        #expect(result.count == 1)
        #expect(result.first?.enhancedText == "Enhanced version")
    }

    // MARK: - Transcription by ID Tests

    @Test func transcriptionById_existingId_returnsTranscription() throws {
        let controller = makeDataController()

        let transcription = createTranscription(text: "Find me")
        controller.modelContext.insert(transcription)
        try controller.modelContext.save()

        let result = try controller.transcription(byId: transcription.id)

        #expect(result != nil)
        #expect(result?.text == "Find me")
    }

    @Test func transcriptionById_nonExistingId_returnsNil() throws {
        let controller = makeDataController()

        let transcription = createTranscription(text: "Exists")
        controller.modelContext.insert(transcription)
        try controller.modelContext.save()

        let nonExistentId = UUID()
        let result = try controller.transcription(byId: nonExistentId)

        #expect(result == nil)
    }

    @Test func transcriptionById_emptyDatabase_returnsNil() throws {
        let controller = makeDataController()

        let result = try controller.transcription(byId: UUID())

        #expect(result == nil)
    }

    // MARK: - Transcription Entities Tests

    @Test func transcriptionEntities_convertsToEntities() throws {
        let controller = makeDataController()

        let transcription = createTranscription(
            text: "Entity test",
            enhancedText: "Enhanced entity",
            audioDuration: 30.0
        )
        controller.modelContext.insert(transcription)
        try controller.modelContext.save()

        let entities = try controller.transcriptionEntities()

        #expect(entities.count == 1)
        let entity = entities.first!
        #expect(entity.id == transcription.id)
        #expect(entity.text == "Entity test")
        #expect(entity.enhancedText == "Enhanced entity")
        #expect(entity.audioDuration == 30.0)
    }

    @Test func transcriptionEntities_withLimit_respectsLimit() throws {
        let controller = makeDataController()

        for i in 1...5 {
            controller.modelContext.insert(createTranscription(text: "Note \(i)"))
        }
        try controller.modelContext.save()

        let entities = try controller.transcriptionEntities(limit: 2)

        #expect(entities.count == 2)
    }

    @Test func transcriptionEntities_withPredicate_filtersCorrectly() throws {
        let controller = makeDataController()

        let longAudio = createTranscription(text: "Long", audioDuration: 120.0)
        let shortAudio = createTranscription(text: "Short", audioDuration: 10.0)
        controller.modelContext.insert(longAudio)
        controller.modelContext.insert(shortAudio)
        try controller.modelContext.save()

        let entities = try controller.transcriptionEntities(matching: #Predicate {
            $0.audioDuration > 60
        })

        #expect(entities.count == 1)
        #expect(entities.first?.text == "Long")
    }

    // MARK: - Transcription Count Tests

    @Test func transcriptionCount_emptyDatabase_returnsZero() throws {
        let controller = makeDataController()

        let count = try controller.transcriptionCount()

        #expect(count == 0)
    }

    @Test func transcriptionCount_withData_returnsCorrectCount() throws {
        let controller = makeDataController()

        controller.modelContext.insert(createTranscription(text: "One"))
        controller.modelContext.insert(createTranscription(text: "Two"))
        controller.modelContext.insert(createTranscription(text: "Three"))
        try controller.modelContext.save()

        let count = try controller.transcriptionCount()

        #expect(count == 3)
    }

    @Test func transcriptionCount_withPredicate_countsFilteredResults() throws {
        let controller = makeDataController()

        // Create transcriptions with different dates
        let recent = createTranscription(text: "Recent", daysAgo: 5)
        let old = createTranscription(text: "Old", daysAgo: 45)
        controller.modelContext.insert(recent)
        controller.modelContext.insert(old)
        try controller.modelContext.save()

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let count = try controller.transcriptionCount(matching: #Predicate {
            $0.timestamp > cutoff
        })

        #expect(count == 1)
    }

    // MARK: - Edge Cases

    @Test func fetchTranscriptions_limitZero_meansNoLimit() throws {
        let controller = makeDataController()

        controller.modelContext.insert(createTranscription(text: "Test"))
        try controller.modelContext.save()

        // In SwiftData, fetchLimit = 0 means no limit (returns all results)
        let result = try controller.transcriptions(limit: 0)

        #expect(result.count == 1)
    }

    @Test func fetchTranscriptions_limitLargerThanData_returnsAllData() throws {
        let controller = makeDataController()

        controller.modelContext.insert(createTranscription(text: "Only one"))
        try controller.modelContext.save()

        let result = try controller.transcriptions(limit: 100)

        #expect(result.count == 1)
    }
}
