//
//  SettingsManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import Foundation

@Observable
class SettingsManager {
    
    // MARK: - Model Settings
    
    func saveSelectedModel(_ model: WhisperModel) {
        UserDefaults.standard.set(model.rawValue, forKey: "selectedLocalWhisperModel")
    }
    
    func loadSelectedModel() -> WhisperModel? {
        guard let selectedModelKey = UserDefaults.standard.string(forKey: "selectedLocalWhisperModel"),
              let selectedModel = WhisperModel(rawValue: selectedModelKey) else {
            return nil
        }
        return selectedModel
    }
    
    // MARK: - Language Settings
    
    func saveSelectedLanguage(_ language: Language) {
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguageKey")
    }
    
    func loadSelectedLanguage() -> Language {
        guard let selectedLanguageKey = UserDefaults.standard.string(forKey: "selectedLanguageKey"),
              let savedSelectedLanguage = Language(rawValue: selectedLanguageKey) else {
            return .auto // Default fallback
        }
        return savedSelectedLanguage
    }
    
    // MARK: - Utility
    
    func clearAllSettings() {
        UserDefaults.standard.removeObject(forKey: "selectedLocalWhisperModel")
        UserDefaults.standard.removeObject(forKey: "selectedLanguageKey")
    }
}