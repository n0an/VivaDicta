//
//  FlowMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct FlowMode: Identifiable, Hashable, Codable {
    let id: UUID

    let name: String
    let transcriptionProvider: TranscriptionModelProvider
    let transcriptionModel: String
    let transcriptionLanguage: String?

    let promptID: UUID?
    let prompt: String
    let promptName: String?
    var aiProvider: AIProvider?
    var aiModel: String

    let aiEnhanceEnabled: Bool

    init(id: UUID,
         name: String,
         transcriptionProvider: TranscriptionModelProvider,
         transcriptionModel: String,
         transcriptionLanguage: String? = nil,
         promptID: UUID? = nil,
         prompt: String,
         promptName: String? = nil,
         aiProvider: AIProvider? = nil,
         aiModel: String,
         aiEnhanceEnabled: Bool) {
        self.id = id
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguage = transcriptionLanguage
        self.promptID = promptID
        self.prompt = prompt
        self.promptName = promptName
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiEnhanceEnabled = aiEnhanceEnabled
    }
    
    static let defaultMode = FlowMode(
        id: UUID(),
        name: "Default",
        transcriptionProvider: .local,
        transcriptionModel: "",
        transcriptionLanguage: "auto",
        prompt: "",
        aiModel: "",
        aiEnhanceEnabled: false)
}
