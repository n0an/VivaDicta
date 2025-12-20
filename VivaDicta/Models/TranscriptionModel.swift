//
//  TranscriptionModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

protocol TranscriptionModel: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var provider: TranscriptionModelProvider { get }
    var recommended: Bool { get }
    
    // Language capabilities
    var supportManyLanguages: Bool { get }
    var supportedLanguages: [String: String] { get }
}

extension TranscriptionModel {
    var language: String {
        supportManyLanguages ? "Multilingual" : "English-only"
    }
}
