//
//  AIEnhanceMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AIEnhanceMode: Identifiable, Hashable, Codable {
    var id: String { name }
    
    let name: String
    let transcriptionProvider: TranscriptionModelProvider
    let transcriptionModel: String
    
    let prompt: String
    var aiProvider: AIProvider?
    var aiModel: String
    
    let aiEnhanceEnabled: Bool
    
    static let defaultMode = AIEnhanceMode(
        name: "Default",
        transcriptionProvider: .local,
        transcriptionModel: "base",
        prompt: "",
        aiModel: "",
        aiEnhanceEnabled: false)
    
//    static let predefinedModes: [AIEnhanceMode] = PromptsTemplates.allCases.map { $0.aiEnhanceMode }
    
}
