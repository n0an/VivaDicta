//
//  FlowMode.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

// FlowMode for keyboard extension - must match the main app's structure for decoding
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

    static let defaultMode = FlowMode(
        id: UUID(),
        name: "Default",
        transcriptionProvider: .local,
        transcriptionModel: "",
        transcriptionLanguage: "auto",
        userPrompt: nil,
        aiProvider: nil,
        aiModel: "",
        aiEnhanceEnabled: false
    )
}

// Supporting types needed for decoding
enum TranscriptionModelProvider: String, Codable {
    case local = "local"
    case openai = "openai"
    case elevenlabs = "elevenlabs"
    case groq = "groq"
    case deepgram = "deepgram"
    case gemini = "gemini"
}

struct UserPrompt: Codable, Hashable {
    let text: String
}

enum AIProvider: String, Codable {
    case openai = "openai"
    case anthropic = "anthropic"
    case openRouter = "openRouter"
}
