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
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        promptInstructions: String,
        useSystemTemplate: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.promptInstructions = promptInstructions
        self.useSystemTemplate = useSystemTemplate
        self.createdAt = createdAt
    }
}
