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
    let description: String
    let promptInstructions: String
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        promptInstructions: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.promptInstructions = promptInstructions
        self.createdAt = createdAt
    }
}
