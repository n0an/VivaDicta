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
    case transcriptionModels
    
    // Dictionary
    case correctSpelling
    case replacements
}
