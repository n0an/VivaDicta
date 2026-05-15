//
//  PresetSyncing.swift
//  Presets
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation

/// Abstraction over the SwiftData/CloudKit backing store that mirrors preset
/// changes. The concrete implementation lives in the app target (where the
/// `ModelContainer` and CloudKit container are configured); the package only
/// depends on this protocol so `PresetManager` can be tested with a mock.
public protocol PresetSyncing: AnyObject {
    func createPresetRecord(from preset: Preset)
    func updatePresetRecord(from preset: Preset)
    func deletePresetRecord(presetId: String)
    func syncBuiltInPresetRecord(from preset: Preset)
    func resetBuiltInPresetRecord(presetId: String)
    func syncFavoriteState(presetId: String, isFavorite: Bool)
}
