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
    case spanish
    case russian

    public var id: String { rawValue }

    /// Two-letter code rendered on the in-keyboard cycle button.
    public var code: String {
        switch self {
        case .english: "EN"
        case .french: "FR"
        case .german: "DE"
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
        case .spanish: "QWERTY + ñ"
        case .russian: "ЙЦУКЕН"
        }
    }
}
