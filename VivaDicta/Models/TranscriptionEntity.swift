//
//  TranscriptionEntity.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import CoreSpotlight

struct TranscriptionEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static let defaultQuery = TranscriptionEntityDefaultQuery()

    // MARK: - Properties

    var id: UUID

    /// Original transcription text - exposed to Shortcuts
    @Property var text: String

    /// AI-enhanced text - exposed to Shortcuts
    @Property(title: "Enhanced Text")
    var enhancedText: String?

    /// Timestamp - exposed to Shortcuts
    @Property var timestamp: Date

    /// Audio duration - exposed to Shortcuts
    @Property(title: "Duration")
    var audioDuration: TimeInterval

    // Internal properties (not exposed to Shortcuts)
    var audioFileName: String?
    var transcriptionModelName: String?
    var aiEnhancementModelName: String?
    var promptName: String?
    var transcriptionDuration: TimeInterval?
    var enhancementDuration: TimeInterval?

    // MARK: - Initialization

    init(
        id: UUID,
        text: String,
        enhancedText: String? = nil,
        timestamp: Date,
        audioDuration: TimeInterval,
        audioFileName: String? = nil,
        transcriptionModelName: String? = nil,
        aiEnhancementModelName: String? = nil,
        promptName: String? = nil,
        transcriptionDuration: TimeInterval? = nil,
        enhancementDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.text = text
        self.enhancedText = enhancedText
        self.timestamp = timestamp
        self.audioDuration = audioDuration
        self.audioFileName = audioFileName
        self.transcriptionModelName = transcriptionModelName
        self.aiEnhancementModelName = aiEnhancementModelName
        self.promptName = promptName
        self.transcriptionDuration = transcriptionDuration
        self.enhancementDuration = enhancementDuration
    }

    // MARK: - Spotlight Indexing (iOS 18+)

    var searchableAttributes: CSSearchableItemAttributeSet {
        let attributeSet = defaultAttributeSet

        let textToUse = enhancedText ?? text

        // Title: First 100 characters of the transcription or a date-based title
        let textPreview = String(textToUse.prefix(100))
        let dateString = timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())

        if textToUse.count > 100 {
            attributeSet.title = "\(textPreview)..."
        } else if !textToUse.isEmpty {
            attributeSet.title = textPreview
        } else {
            attributeSet.title = "Recording - \(dateString)"
        }

        // Content: Full text for searching (original + enhanced)
        var fullContent = text
        if let enhancedText = enhancedText, !enhancedText.isEmpty {
            fullContent += "\n\n" + enhancedText
        }
        attributeSet.contentDescription = fullContent

        // Keywords: Model names, prompt
        var keywords = [String]()
        if let promptName = promptName { keywords.append(promptName) }
        if let transcriptionModel = transcriptionModelName { keywords.append(transcriptionModel) }
        if let aiModel = aiEnhancementModelName { keywords.append(aiModel) }
        attributeSet.keywords = keywords

        // Duration and dates
        attributeSet.duration = NSNumber(value: audioDuration)
        attributeSet.contentCreationDate = timestamp
        attributeSet.contentModificationDate = timestamp
        attributeSet.addedDate = timestamp

        // Additional metadata
        attributeSet.kind = "Voice Transcription"
        attributeSet.identifier = id.uuidString
        attributeSet.relatedUniqueIdentifier = id.uuidString

        return attributeSet
    }

    // MARK: - Display Helpers

    func text(withPrefix prefix: Int = 50) -> String {
        let textToUse = enhancedText ?? text
        return String(textToUse.prefix(prefix))
    }

    var subtitle: String {
        timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(text(withPrefix: 50))",
            subtitle: "\(subtitle)",
            image: .init(systemName: "text.page")
        )
    }
}



struct TranscriptionEntityDefaultQuery: EnumerableEntityQuery {
    @Dependency var dataController: DataController
    
    func allEntities() async throws -> [TranscriptionEntity] {
        try await dataController.transcriptionEntities()
    }

    func entities(for identifiers: [UUID]) async throws -> [TranscriptionEntity] {
        try await dataController.transcriptionEntities(matching: #Predicate {
            identifiers.contains($0.id)
        })
    }
    
}
