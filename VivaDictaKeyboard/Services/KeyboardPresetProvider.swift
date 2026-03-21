//
//  KeyboardPresetProvider.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import Foundation

/// Loads presets for the keyboard extension UI from shared UserDefaults.
///
/// The main app's `PresetManager` persists presets to the shared app group UserDefaults
/// under key `"Presets_v1"`. This provider reads that same data so the keyboard
/// can display available presets without depending on `PresetManager` or SwiftData.
final class KeyboardPresetProvider {

    private let userDefaults: UserDefaults
    private let storageKey = "Presets_v1"

    init() {
        self.userDefaults = UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)!
    }

    /// Loads all available presets, sorted with favorites first.
    func loadPresets() -> [Preset] {
        guard let data = userDefaults.data(forKey: storageKey),
              let presets = try? JSONDecoder().decode([Preset].self, from: data),
              !presets.isEmpty else {
            return PresetCatalog.allBuiltIn
        }
        return presets
    }

    /// Returns presets organized by category, with favorites section first if any exist.
    func loadGroupedPresets() -> [(category: String, presets: [Preset])] {
        let all = loadPresets()

        var groups: [(category: String, presets: [Preset])] = []

        // Favorites first
        let favorites = all.filter(\.isFavorite)
        if !favorites.isEmpty {
            groups.append(("Favorites", favorites))
        }

        // Then by category (using PresetCatalog ordering)
        var seen = Set<String>()
        var categoryOrder: [String] = []
        for preset in all {
            if !seen.contains(preset.category) {
                seen.insert(preset.category)
                categoryOrder.append(preset.category)
            }
        }

        let sorted = categoryOrder.sorted { lhs, rhs in
            let lhsIdx = PresetCatalog.categoryOrder.firstIndex(of: lhs) ?? Int.max
            let rhsIdx = PresetCatalog.categoryOrder.firstIndex(of: rhs) ?? Int.max
            if lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
            return lhs < rhs
        }

        for category in sorted {
            let categoryPresets = all.filter { $0.category == category }
            groups.append((category, categoryPresets))
        }

        return groups
    }
}
