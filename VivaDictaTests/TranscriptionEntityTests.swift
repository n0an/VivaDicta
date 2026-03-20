//
//  TranscriptionEntityTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.17
//

import CoreSpotlight
import Foundation
import Testing
@testable import VivaDicta

struct TranscriptionEntityTests {

    // MARK: - Entity Creation from Transcription Tests

    @Test func entityFromTranscription_copiesAllProperties() {
        let transcription = Transcription(
            text: "Original text",
            enhancedText: "Enhanced text",
            audioDuration: 45.5,
            audioFileName: "recording.m4a",
            transcriptionModelName: "whisper-large",
            aiEnhancementModelName: "gpt-4",
            promptName: "Note",
            transcriptionDuration: 2.5,
            enhancementDuration: 1.2
        )

        let entity = transcription.entity

        #expect(entity.id == transcription.id)
        #expect(entity.text == "Original text")
        #expect(entity.enhancedText == "Enhanced text")
        #expect(entity.timestamp == transcription.timestamp)
        #expect(entity.audioDuration == 45.5)
        #expect(entity.audioFileName == "recording.m4a")
        #expect(entity.transcriptionModelName == "whisper-large")
        #expect(entity.aiEnhancementModelName == "gpt-4")
        #expect(entity.promptName == "Note")
        #expect(entity.transcriptionDuration == 2.5)
        #expect(entity.enhancementDuration == 1.2)
    }

    @Test func entityFromTranscription_handlesNilOptionals() {
        let transcription = Transcription(
            text: "Basic text",
            audioDuration: 10.0
        )

        let entity = transcription.entity

        #expect(entity.enhancedText == nil)
        #expect(entity.audioFileName == nil)
        #expect(entity.transcriptionModelName == nil)
        #expect(entity.aiEnhancementModelName == nil)
        #expect(entity.promptName == nil)
        #expect(entity.transcriptionDuration == nil)
        #expect(entity.enhancementDuration == nil)
    }

    // MARK: - Text With Prefix Tests

    @Test func textWithPrefix_usesAIProcessedTextWhenAvailable() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Original text",
            enhancedText: "Enhanced text",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let result = entity.text(withPrefix: 50)

        #expect(result == "Enhanced text")
    }

    @Test func textWithPrefix_usesOriginalTextWhenNoAIProcessed() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Original text only",
            enhancedText: nil,
            timestamp: Date(),
            audioDuration: 10.0
        )

        let result = entity.text(withPrefix: 50)

        #expect(result == "Original text only")
    }

    @Test func textWithPrefix_truncatesLongText() {
        let longText = String(repeating: "a", count: 100)
        let entity = TranscriptionEntity(
            id: UUID(),
            text: longText,
            timestamp: Date(),
            audioDuration: 10.0
        )

        let result = entity.text(withPrefix: 10)

        #expect(result.count == 10)
        #expect(result == "aaaaaaaaaa")
    }

    @Test func textWithPrefix_defaultsTo50Characters() {
        let longText = String(repeating: "b", count: 100)
        let entity = TranscriptionEntity(
            id: UUID(),
            text: longText,
            timestamp: Date(),
            audioDuration: 10.0
        )

        let result = entity.text()

        #expect(result.count == 50)
    }

    @Test func textWithPrefix_handlesShortText() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Short",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let result = entity.text(withPrefix: 50)

        #expect(result == "Short")
    }

    @Test func textWithPrefix_handlesEmptyText() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let result = entity.text(withPrefix: 50)

        #expect(result == "")
    }

    // MARK: - Subtitle Tests

    @Test func subtitle_formatsDateCorrectly() {
        // Create a specific date for testing
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components)!

        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Test",
            timestamp: date,
            audioDuration: 10.0
        )

        let subtitle = entity.subtitle

        // Subtitle should contain date components
        #expect(subtitle.contains("Jun"))
        #expect(subtitle.contains("15"))
        #expect(subtitle.contains("2025"))
    }

    // MARK: - Searchable Attributes Tests

    @Test func searchableAttributes_setsTitle_fromShortText() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Short note",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.title == "Short note")
    }

    @Test func searchableAttributes_setsTitle_fromAIProcessedTextWhenAvailable() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Original",
            enhancedText: "Enhanced version",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.title == "Enhanced version")
    }

    @Test func searchableAttributes_truncatesTitleOver100Chars() {
        let longText = String(repeating: "x", count: 150)
        let entity = TranscriptionEntity(
            id: UUID(),
            text: longText,
            timestamp: Date(),
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.title?.hasSuffix("...") == true)
        #expect(attributes.title?.count == 103) // 100 chars + "..."
    }

    @Test func searchableAttributes_setsFallbackTitle_forEmptyText() {
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 10
        components.hour = 9
        components.minute = 45
        let date = Calendar.current.date(from: components)!

        let entity = TranscriptionEntity(
            id: UUID(),
            text: "",
            timestamp: date,
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.title?.hasPrefix("Recording -") == true)
    }

    @Test func searchableAttributes_setsContentDescription() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Original text",
            enhancedText: "Enhanced text",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.contentDescription?.contains("Original text") == true)
        #expect(attributes.contentDescription?.contains("Enhanced text") == true)
    }

    @Test func searchableAttributes_setsKeywords() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Test",
            timestamp: Date(),
            audioDuration: 10.0,
            transcriptionModelName: "whisper",
            aiEnhancementModelName: "gpt-4",
            promptName: "Note"
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.keywords?.contains("whisper") == true)
        #expect(attributes.keywords?.contains("gpt-4") == true)
        #expect(attributes.keywords?.contains("Note") == true)
    }

    @Test func searchableAttributes_setsDuration() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Test",
            timestamp: Date(),
            audioDuration: 123.5
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.duration == NSNumber(value: 123.5))
    }

    @Test func searchableAttributes_setsDates() {
        let testDate = Date()
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Test",
            timestamp: testDate,
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.contentCreationDate == testDate)
        #expect(attributes.contentModificationDate == testDate)
        #expect(attributes.addedDate == testDate)
    }

    @Test func searchableAttributes_setsIdentifier() {
        let id = UUID()
        let entity = TranscriptionEntity(
            id: id,
            text: "Test",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.identifier == id.uuidString)
        #expect(attributes.relatedUniqueIdentifier == id.uuidString)
    }

    @Test func searchableAttributes_setsKind() {
        let entity = TranscriptionEntity(
            id: UUID(),
            text: "Test",
            timestamp: Date(),
            audioDuration: 10.0
        )

        let attributes = entity.searchableAttributes

        #expect(attributes.kind == "Voice Transcription")
    }

    // MARK: - Display Representation Tests

    @Test func displayRepresentation_usesTextPrefix() {
        let longText = String(repeating: "z", count: 100)
        let entity = TranscriptionEntity(
            id: UUID(),
            text: longText,
            timestamp: Date(),
            audioDuration: 10.0
        )

        // Verify that text(withPrefix:) returns 50 chars, which is used in displayRepresentation
        let textPrefix = entity.text(withPrefix: 50)
        #expect(textPrefix.count == 50)
    }

    // MARK: - Type Display Representation Tests

    @Test func typeDisplayRepresentation_exists() {
        // TypeDisplayRepresentation is set to "Note"
        // Verify the static property is accessible (compile-time check)
        _ = TranscriptionEntity.typeDisplayRepresentation
        // If we got here without crash, the property exists
    }
}
