//
//  SettingsDestination.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import Foundation

enum SettingsDestination: Hashable {
    case aiProviders
    case promptsSettings
    case promptsTemplates
    case presetsSettings
    case transcriptionModels
    case chatTools
    case geminiTranscriptionPrompt

    // Dictionary
    case correctSpelling
    case replacements

    // Organization
    case tags
    case autoDeleteExemptTags

    // Smart Search
    case smartSearch

    // Integrations
    case integrations

    // Export
    case export

    // Advanced
    case advanced
}
