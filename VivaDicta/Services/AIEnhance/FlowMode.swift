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

    let userPrompt: UserPrompt?
    var aiProvider: AIProvider?
    var aiModel: String

    let aiEnhanceEnabled: Bool

    init(id: UUID,
         name: String,
         transcriptionProvider: TranscriptionModelProvider,
         transcriptionModel: String,
         transcriptionLanguage: String? = nil,
         userPrompt: UserPrompt? = nil,
         aiProvider: AIProvider? = nil,
         aiModel: String,
         aiEnhanceEnabled: Bool) {
        self.id = id
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguage = transcriptionLanguage
        self.userPrompt = userPrompt
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiEnhanceEnabled = aiEnhanceEnabled
    }
    
    static let defaultMode = FlowMode(
        id: UUID(),
        name: "Default",
        transcriptionProvider: .whisperKit,
        transcriptionModel: "",
        transcriptionLanguage: "auto",
        userPrompt: nil,
        aiModel: "",
        aiEnhanceEnabled: false)
}
