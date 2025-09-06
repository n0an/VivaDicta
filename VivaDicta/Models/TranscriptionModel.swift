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
    
    // Language capabilities
    var supportManyLanguages: Bool { get }
    var supportedLanguages: [String: String] { get }
}

extension TranscriptionModel {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var language: String {
        supportManyLanguages ? "Multilingual" : "English-only"
    }
}
