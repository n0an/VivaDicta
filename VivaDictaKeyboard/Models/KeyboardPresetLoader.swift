//
//  KeyboardPresetLoader.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.29
//

import Foundation

/// Loads presets from shared App Group UserDefaults for display in the keyboard extension.
///
/// The keyboard doesn't have access to `PresetManager`, but `Preset` and `PresetCatalog`
/// are available via target membership. This loader reads the persisted preset array directly.
enum KeyboardPresetLoader {
    private static let storageKey = "Presets_v1"

    /// Loads all presets from shared UserDefaults.
    static func loadPresets() -> [Preset] {
        guard let defaults = UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId),
              let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }
}
