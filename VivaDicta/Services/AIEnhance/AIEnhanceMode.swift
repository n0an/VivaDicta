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
        DefaultPrompts.email.aiEnhanceMode,
        DefaultPrompts.chat.aiEnhanceMode,
        DefaultPrompts.note.aiEnhanceMode,
        DefaultPrompts.regular.aiEnhanceMode        
    ]
    
    
}
