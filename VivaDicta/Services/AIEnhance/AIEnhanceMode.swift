//
//  AIEnhanceMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AIEnhanceMode: Identifiable, Hashable, Codable {
    let name: String
    let prompt: String
    var aiProvider: AIProvider?
    var aiModel: String
    
    let aiEnhanceEnabled: Bool
    
    var id: String { name }
    
    static let predefinedModes: [AIEnhanceMode] = [
        AIEnhanceMode(
            name: "Email",
            prompt: DefaultPrompts.email.prompt,
            aiProvider: nil,
            aiModel: "",
            aiEnhanceEnabled: false
        ),
        AIEnhanceMode(
            name: "Chat",
            prompt: DefaultPrompts.chat.prompt,
            aiProvider: nil,
            aiModel: "",
            aiEnhanceEnabled: false
        ),
        AIEnhanceMode(
            name: "Note",
            prompt: DefaultPrompts.note.prompt,
            aiProvider: nil,
            aiModel: "",
            aiEnhanceEnabled: false
        ),
        AIEnhanceMode(
            name: "Regular",
            prompt: DefaultPrompts.regular.prompt,
            aiProvider: nil,
            aiModel: "",
            aiEnhanceEnabled: false
        )
    ]
}
