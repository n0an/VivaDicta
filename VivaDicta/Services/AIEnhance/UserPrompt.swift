//
//  UserPrompt.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import Foundation

struct UserPrompt: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let title: String
    let promptInstructions: String
    let useSystemTemplate: Bool
    let wrapInTranscriptTags: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        promptInstructions: String,
        useSystemTemplate: Bool = true,
        wrapInTranscriptTags: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.promptInstructions = promptInstructions
        self.useSystemTemplate = useSystemTemplate
        self.wrapInTranscriptTags = wrapInTranscriptTags
        self.createdAt = createdAt
    }

    // Custom decoder to handle migration from older versions without wrapInTranscriptTags
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        promptInstructions = try container.decode(String.self, forKey: .promptInstructions)
        useSystemTemplate = try container.decode(Bool.self, forKey: .useSystemTemplate)
        wrapInTranscriptTags = try container.decodeIfPresent(Bool.self, forKey: .wrapInTranscriptTags) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
