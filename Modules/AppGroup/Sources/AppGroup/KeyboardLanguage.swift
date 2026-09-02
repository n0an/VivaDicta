//
//  KeyboardLanguage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.04
//

import Foundation

/// A language the VivaDicta custom keyboard can render.
///
/// Each case maps to a specific letter layout (QWERTY, AZERTY, QWERTZ, etc.)
/// and a callout table for long-press alternates. Shared between the main app
/// (Settings UI) and the keyboard extension (layout dispatcher) via
/// `AppGroupCoordinator`.
///
/// `allCases` order is the canonical cycle order used by the in-keyboard
/// language toggle key when 2+ languages are enabled.
public enum KeyboardLanguage: String, CaseIterable, Sendable, Hashable, Identifiable {
    case english
    case french
    case german
    case czech
    case spanish
    case russian

    public var id: String { rawValue }

    /// Two-letter code rendered on the in-keyboard cycle button.
    public var code: String {
        switch self {
        case .english: "EN"
        case .french: "FR"
        case .german: "DE"
        case .czech: "CZ"
        case .spanish: "ES"
        case .russian: "RU"
        }
    }

    /// Native-language name shown in Settings.
    public var displayName: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .german: "Deutsch"
        case .czech: "Čeština"
        case .spanish: "Español"
        case .russian: "Русский"
        }
    }

    /// Short layout descriptor shown as a Settings subtitle.
    public var layoutDescription: String {
        switch self {
        case .english: "QWERTY"
        case .french: "AZERTY"
        case .german: "QWERTZ"
        case .czech: "QWERTZ"
        case .spanish: "QWERTY + ñ"
        case .russian: "ЙЦУКЕН"
        }
    }

    /// BCP-47 language codes that should map to this `KeyboardLanguage` when
    /// inspecting the user's iOS preferred-languages list. Multiple codes are
    /// listed where dialects are common (e.g. en, en-US, en-GB all map to
    /// English).
    private var matchingLanguageCodes: Set<String> {
        switch self {
        case .english: ["en"]
        case .french: ["fr"]
        case .german: ["de"]
        case .czech: ["cs"]
        case .spanish: ["es"]
        case .russian: ["ru"]
        }
    }

    /// Inspects `Locale.preferredLanguages` (the user's iOS-level language
    /// preference list, set in iOS Settings -> General -> Language & Region)
    /// and returns the subset of `KeyboardLanguage` cases that match.
    ///
    /// Used during the one-shot onboarding migration to pre-check toggles for
    /// languages the user is likely to want. After that first run the user's
    /// explicit choices take precedence.
    public static func preferredFromSystem() -> Set<KeyboardLanguage> {
        var result: Set<KeyboardLanguage> = []
        for tag in Locale.preferredLanguages {
            // Locale(identifier:).language.languageCode gives the primary
            // language code without region (e.g. "en-US" -> "en").
            guard let code = Locale(identifier: tag).language.languageCode?.identifier else { continue }
            for language in KeyboardLanguage.allCases {
                if language.matchingLanguageCodes.contains(code) {
                    result.insert(language)
                }
            }
        }
        return result
    }
}
