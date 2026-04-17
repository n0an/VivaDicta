//
//  ChineseScriptPreference.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.17
//

import Foundation

/// User preference for the Chinese script used in AI-enhanced output.
/// The preference is appended as a short hint to the AI system message, so it
/// only affects text that the model is already producing in Chinese. Non-Chinese
/// output is untouched regardless of this setting.
enum ChineseScriptPreference: String, CaseIterable, Identifiable, Sendable {
    case auto
    case simplified
    case traditional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .simplified: return "Simplified (简体)"
        case .traditional: return "Traditional (繁體)"
        }
    }

    /// Instruction appended to the AI system message. `nil` for `.auto` so the
    /// prompt stays untouched for users who never configured this.
    var systemMessageSuffix: String? {
        switch self {
        case .auto:
            return nil
        case .simplified:
            return "\n\nWhen the output is in Chinese, use Simplified Chinese characters (简体中文)."
        case .traditional:
            return "\n\nWhen the output is in Chinese, use Traditional Chinese characters (繁體中文)."
        }
    }
}

enum ChineseScriptPreferenceStore {
    private static let userDefaultsKey = "preferredChineseScript"

    static var current: ChineseScriptPreference {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let preference = ChineseScriptPreference(rawValue: raw) else {
                return .auto
            }
            return preference
        }
        set {
            if newValue == .auto {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
            }
        }
    }

    /// Whether to surface the preference row in Settings. True when the user
    /// has signaled Chinese usage in any of: device preferred languages, any
    /// mode's transcription language, or the global selected language.
    static func shouldShowSetting(modes: [VivaMode]) -> Bool {
        if Locale.preferredLanguages.contains(where: { $0.hasPrefix("zh") }) {
            return true
        }
        if modes.contains(where: { ($0.transcriptionLanguage ?? "").hasPrefix("zh") }) {
            return true
        }
        if let selected = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kSelectedLanguageKey),
           selected.hasPrefix("zh") {
            return true
        }
        return false
    }
}
