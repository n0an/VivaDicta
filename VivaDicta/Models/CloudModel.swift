//
//  CloudModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

struct CloudModel: TranscriptionModel, Identifiable {
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

extension CloudModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CloudModel, rhs: CloudModel) -> Bool {
        lhs.id == rhs.id
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
