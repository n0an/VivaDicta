//
//  AIEnhanceMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AIEnhanceMode: Identifiable, Hashable, Codable {
    let id: UUID

    let name: String
    let transcriptionProvider: TranscriptionModelProvider
    let transcriptionModel: String

    let promptID: UUID?
    let prompt: String
    var aiProvider: AIProvider?
    var aiModel: String

    let aiEnhanceEnabled: Bool
    
    init(id: UUID, name: String, transcriptionProvider: TranscriptionModelProvider, transcriptionModel: String, promptID: UUID? = nil, prompt: String, aiProvider: AIProvider? = nil, aiModel: String, aiEnhanceEnabled: Bool) {
        self.id = id
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel
        self.promptID = promptID
        self.prompt = prompt
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiEnhanceEnabled = aiEnhanceEnabled
    }
    
    static let defaultMode = AIEnhanceMode(
        id: UUID(),
        name: "Default",
        transcriptionProvider: .local,
        transcriptionModel: "base",
        prompt: "",
        aiModel: "",
        aiEnhanceEnabled: false)
    
//    static let predefinedModes: [AIEnhanceMode] = PromptsTemplates.allCases.map { $0.aiEnhanceMode }
    
}
