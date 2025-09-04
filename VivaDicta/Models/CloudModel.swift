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

extension CloudModel {
    static func saveApiKey(_ apiKey: String, modelName: String) {
        UserDefaults.standard.set(apiKey, forKey: kAPIKeyTemplate + modelName)
    }
}

extension CloudModel {
    var apiKey: String? {
        get {
            UserDefaults.standard.string(forKey: kAPIKeyTemplate + self.name)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kAPIKeyTemplate + self.name)
        }
    }
}
