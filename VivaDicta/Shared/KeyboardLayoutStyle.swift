//
//  KeyboardLayoutStyle.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.21
//

import Foundation

/// Letter layout for the VivaDicta custom keyboard.
///
/// Shared between the main app (Settings picker) and the keyboard extension
/// (layout builder) via `AppGroupCoordinator`.
public enum KeyboardLayoutStyle: String, CaseIterable, Sendable {
    case qwerty
    case azerty

    public var displayName: String {
        switch self {
        case .qwerty: "QWERTY"
        case .azerty: "AZERTY"
        }
    }
}
