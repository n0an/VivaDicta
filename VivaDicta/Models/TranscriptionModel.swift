//
//  TranscriptionModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

enum TranscriptionModelProvider {
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
    var provider: TranscriptionModelProvider { get }
    
    // Language capabilities
    var supportManyLanguages: Bool { get }
    var supportedLanguages: [String: String] { get }
}

struct WhisperLocalModel: @MainActor TranscriptionModel {
    var id: UUID = .init()
    var name: String
    var displayName: String
    var description: String
    var provider: TranscriptionModelProvider = .local
    
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    var supportManyLanguages: Bool {
        supportedLanguages.count > 1
    }
    
    var supportedLanguages: [String: String]
}

struct CloudModel: @MainActor TranscriptionModel {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let provider: TranscriptionModelProvider
    
    let speed: Double
    let accuracy: Double
    let supportManyLanguages: Bool
    let supportedLanguages: [String: String]
    
    init(id: UUID = UUID(),
         name: String,
         displayName: String,
         description: String,
         provider: TranscriptionModelProvider,
         speed: Double,
         accuracy: Double,
         supportManyLanguages: Bool,
         supportedLanguages: [String: String])
    {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.provider = provider
        self.speed = speed
        self.accuracy = accuracy
        self.supportManyLanguages = supportManyLanguages
        self.supportedLanguages = supportedLanguages
    }
}
