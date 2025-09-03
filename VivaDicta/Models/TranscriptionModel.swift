//
//  TranscriptionModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

enum ModelProvider {
    case local
    case parakeet
    case groq
    case elevenLabs
    case deepgram
    case gemini
}

protocol TranscriptionModel: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var provider: ModelProvider { get }
    
    // Language capabilities
    var isMultilingualModel: Bool { get }
    var supportedLanguages: [String: String] { get }
}


struct WhisperLocalModel: @MainActor TranscriptionModel {
    var id: UUID = UUID()
    var name: String
    var displayName: String
    var description: String
    var provider: ModelProvider = .local
    
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    var isMultilingualModel: Bool {
        supportedLanguages.count > 1
    }
    var supportedLanguages: [String : String]
    
    
}

