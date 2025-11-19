//
//  CloudModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

struct CloudModel: @MainActor TranscriptionModel {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let provider: TranscriptionModelProvider
    let recommended: Bool

    let speed: Double
    let accuracy: Double
    let cost: Double  // 0-1 scale: 0.1 = very cheap, 1.0 = expensive
    let supportManyLanguages: Bool
    let supportedLanguages: [String: String]

    init(id: UUID = UUID(),
         name: String,
         displayName: String,
         description: String,
         provider: TranscriptionModelProvider,
         recommended: Bool = false,
         speed: Double,
         accuracy: Double,
         cost: Double = 0.5,
         supportManyLanguages: Bool,
         supportedLanguages: [String: String])
    {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.provider = provider
        self.recommended = recommended
        self.speed = speed
        self.accuracy = accuracy
        self.cost = cost
        self.supportManyLanguages = supportManyLanguages
        self.supportedLanguages = supportedLanguages
    }
}

extension CloudModel {
    var apiKey: String? {
        get {
            // API keys need to be shared with keyboard extension
            return UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue)
        }
    }
}
