//
//  TranscriptionEntity.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import CoreSpotlight
import SwiftData

struct TranscriptionEntity: IndexedEntity {
    var id: UUID

    @Property var text: String

    @Property(title: "Enhanced Text")
    var enhancedText: String?

    @Property var timestamp: Date

    @Property(title: "Duration")
    var audioDuration: TimeInterval

    // Not exposed to Shortcuts - internal use only
    var audioFileName: String?
    var transcriptionModelName: String?
    var aiEnhancementModelName: String?
    var promptName: String?
    var transcriptionDuration: TimeInterval?
    var enhancementDuration: TimeInterval?

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

    var searchableAttributes: CSSearchableItemAttributeSet {
        
        
        let attributeSet = defaultAttributeSet
//        attributeSet.contentDescription = details
//        attributeSet.addedDate = date
        
        
//        let attributes = CSSearchableItemAttributeSet(contentType: .text)

        let textToUse = enhancedText ?? text
        
        // Title: First 100 characters of the transcription or a date-based title
        let textPreview = String(textToUse.prefix(100))
        let dateString = timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
        
        let title: String
        
        if textToUse.count > 100 {
            title = "\(textPreview)..."
        } else if !textToUse.isEmpty {
            title = textPreview
        } else {
            title = "Recording - \(dateString)"
        }
        
        attributeSet.title = title
//        attributeSet.displayName = title

        // Content: Full text for searching (original + enhanced)
        var fullContent = text
        if let enhancedText = enhancedText, !enhancedText.isEmpty {
            fullContent += "\n\n" + enhancedText
        }
        attributeSet.contentDescription = fullContent

        // Keywords: Model names, prompt, and meaningful terms
        var keywords = [String]()

        if let promptName = promptName {
            keywords.append(promptName)
        }

        if let transcriptionModel = transcriptionModelName {
            keywords.append(transcriptionModel)
        }

        if let aiModel = aiEnhancementModelName {
            keywords.append(aiModel)
        }

        // TODO: Add LLM-generated tags to keywords when available
        // if let tags = tags {
        //     keywords.append(contentsOf: tags)
        // }

        attributeSet.keywords = keywords

        // Duration and dates
        attributeSet.duration = NSNumber(value: audioDuration)
        attributeSet.contentCreationDate = timestamp
        attributeSet.contentModificationDate = timestamp

        // Additional metadata
        attributeSet.kind = "Voice Transcription"
        attributeSet.identifier = id.uuidString
        attributeSet.relatedUniqueIdentifier = id.uuidString

        // Audio metadata (if we have it)
        if audioDuration > 0 {
            let durationCategory: String
            switch audioDuration {
            case 0..<30:
                durationCategory = "Short recording"
            case 30..<120:
                durationCategory = "Medium recording"
            default:
                durationCategory = "Long recording"
            }
            attributeSet.comment = durationCategory
        }
        
        attributeSet.addedDate = timestamp
        
        return attributeSet
    }
    
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    
    static let defaultQuery = TranscriptionEntityDefaultQuery()
    
    func text(withPrefix prefix: Int = 50) -> String {
        if let enhancedText {
            return String(enhancedText.prefix(prefix))
        } else {
            return String(text.prefix(prefix))
        }
    }
    
    var subtitle: String {
        return timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(text(withPrefix: 50))", subtitle: "\(subtitle)", image: .init(systemName: "text.page"))
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
