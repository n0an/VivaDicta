//
//  TranscriptionEntity.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import SwiftData

struct TranscriptionEntity: AppEntity {
    var id: UUID
    
    var text: String
    var enhancedText: String?
    var timestamp: Date
    var audioDuration: TimeInterval
    var audioFileName: String?
    var transcriptionModelName: String?
    var aiEnhancementModelName: String?
    var promptName: String?
    var transcriptionDuration: TimeInterval?
    var enhancementDuration: TimeInterval?
    
    
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
