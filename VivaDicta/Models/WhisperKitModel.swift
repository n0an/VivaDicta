//
//  WhisperKitModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import Foundation

struct WhisperKitModel: @MainActor TranscriptionModel, Equatable {
    static func == (lhs: WhisperKitModel, rhs: WhisperKitModel) -> Bool {
        lhs.id == rhs.id
    }

    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: TranscriptionModelProvider = .whisperKit
    let recommended: Bool
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    
    init(name: String,
         displayName: String,
         description: String,
         recommended: Bool = false,
         size: String, speed: Double,
         accuracy: Double,
         ramUsage: Double,
         supportedLanguages: [String : String],
         whisperKitModelName: String) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.recommended = recommended
        self.size = size
        self.speed = speed
        self.accuracy = accuracy
        self.ramUsage = ramUsage
        self.supportedLanguages = supportedLanguages
        self.whisperKitModelName = whisperKitModelName
    }
    
    var supportManyLanguages: Bool {
        supportedLanguages.count > 1
    }
    
    let supportedLanguages: [String: String]
    let whisperKitModelName: String
}

