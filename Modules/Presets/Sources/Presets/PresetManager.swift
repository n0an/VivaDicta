//
//  PresetManager.swift
//  Presets
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import os

/// Manages AI text processing presets with persistence in App Group UserDefaults.
///
/// Handles both built-in and custom presets. Built-in presets are editable but not deletable.
/// Custom presets are synced to CloudKit via a `PresetSync` implementation supplied by
/// the app target (the package itself does not depend on SwiftData/CloudKit).
///
/// ## Storage
///
/// Presets are stored in the `UserDefaults` instance passed in the initializer.
/// Production callers pass the App Group UserDefaults so the keyboard extension
/// can read them too.
@Observable
public class PresetManager {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "PresetManager")
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let hiddenPresetIDsStorageKey: String

    /// All available presets (built-in + custom from UserDefaults).
    public private(set) var presets: [Preset] = []

    /// Preset IDs hidden from pickers and keyboard on this device.
    public private(set) var hiddenPresetIDs: Set<String> = []

    /// Sync service for writing preset changes to SwiftData/CloudKit. The
    /// concrete implementation lives in the app target.
    public var syncService: (any PresetSync)?

    public init(userDefaults: UserDefaults,
                storageKey: String = "Presets_v1",
                hiddenPresetIDsStorageKey: String = "HiddenPresetIDs_v1") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.hiddenPresetIDsStorageKey = hiddenPresetIDsStorageKey
        loadPresets()
        loadHiddenPresetIDs()
        populateBuiltInsIfNeeded()
    }

    // MARK: - Lookup

    /// Returns a preset by its ID.
    public func preset(for id: String) -> Preset? {
        presets.first { $0.id == id }
    }

    /// Returns presets visible in pickers and keyboard on this device.
    public var visiblePresets: [Preset] {
        presets.filter { !hiddenPresetIDs.contains($0.id) }
    }

    /// Returns all presets for a given category.
    public func presets(in category: String) -> [Preset] {
        presets.filter { $0.category == category }
    }

    /// Whether any presets are marked as favorites.
    public var hasFavorites: Bool {
        presets.contains { $0.isFavorite }
    }

    /// Whether any visible presets are marked as favorites.
    public var hasVisibleFavorites: Bool {
        visiblePresets.contains { $0.isFavorite }
    }

    /// Returns ordered category names using explicit category ordering.
    public var categories: [String] {
        categories(from: presets)
    }

    /// Returns ordered category names for presets visible in pickers and keyboard.
    public var visibleCategories: [String] {
        categories(from: visiblePresets)
    }

    /// Returns whether the preset is hidden from pickers and keyboard on this device.
    public func isPresetHidden(presetId: String) -> Bool {
        hiddenPresetIDs.contains(presetId)
    }

    /// Updates whether the preset is hidden from pickers and keyboard on this device.
    public func setPresetHidden(presetId: String, isHidden: Bool) {
        guard preset(for: presetId) != nil else { return }

        if isHidden {
            hiddenPresetIDs.insert(presetId)
        } else {
            hiddenPresetIDs.remove(presetId)
        }

        saveHiddenPresetIDs()
        logger.info("Updated preset visibility: \(presetId, privacy: .public) hidden=\(isHidden)")
    }

    // MARK: - CRUD

    /// Adds a new custom preset.
    public func addPreset(_ preset: Preset) {
        presets.append(preset)
        savePresets()

        if preset.id.hasPrefix("custom_") {
            syncService?.createPresetRecord(from: preset)
        }

        logger.info("Added preset: \(preset.name, privacy: .public)")
    }

    /// Updates an existing preset (matched by ID).
    public func updatePreset(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        savePresets()

        if preset.id.hasPrefix("custom_") {
            syncService?.updatePresetRecord(from: preset)
        } else if preset.isEdited && PresetCatalog.builtInIds.contains(preset.id) {
            syncService?.syncBuiltInPresetRecord(from: preset)
        }

        logger.info("Updated preset: \(preset.name, privacy: .public)")
    }

    /// Deletes a preset. Built-in presets cannot be deleted.
    public func deletePreset(_ preset: Preset) {
        guard !preset.isBuiltIn else {
            logger.warning("Cannot delete built-in preset: \(preset.name, privacy: .public)")
            return
        }
        presets.removeAll { $0.id == preset.id }
        hiddenPresetIDs.remove(preset.id)
        savePresets()
        saveHiddenPresetIDs()

        if preset.id.hasPrefix("custom_") {
            syncService?.deletePresetRecord(presetId: preset.id)
        }

        logger.info("Deleted preset: \(preset.name, privacy: .public)")
    }

    /// Resets a built-in preset to its factory default.
    public func resetToDefault(presetId: String) {
        guard let defaultPreset = PresetCatalog.defaultPreset(for: presetId),
              let index = presets.firstIndex(where: { $0.id == presetId }) else { return }
        presets[index] = defaultPreset
        savePresets()

        syncService?.resetBuiltInPresetRecord(presetId: presetId)

        logger.info("Reset preset to default: \(defaultPreset.name, privacy: .public)")
    }

    /// Toggles the favorite state of a preset and syncs to CloudKit.
    public func toggleFavorite(presetId: String) {
        guard let index = presets.firstIndex(where: { $0.id == presetId }) else { return }
        presets[index].isFavorite.toggle()
        savePresets()
        syncService?.syncFavoriteState(presetId: presetId, isFavorite: presets[index].isFavorite)
        logger.info("Toggled favorite: \(self.presets[index].name, privacy: .public) -> \(self.presets[index].isFavorite)")
    }

    /// Checks if a preset name already exists (for duplicate detection).
    public func isPresetNameDuplicate(_ name: String, excludingId: String? = nil) -> Bool {
        let normalizedName = normalizeForComparison(name)
        return presets.contains { preset in
            normalizeForComparison(preset.name) == normalizedName && preset.id != excludingId
        }
    }

    // MARK: - Built-In Management

    /// Populates built-in presets on first launch and syncs catalog fields
    /// for existing built-in presets. Non-edited presets get fully refreshed;
    /// edited presets only get category and icon updated.
    private func populateBuiltInsIfNeeded() {
        var changed = false
        for builtIn in PresetCatalog.allBuiltIn {
            if let index = presets.firstIndex(where: { $0.id == builtIn.id }) {
                if presets[index].isEdited {
                    if presets[index].category != builtIn.category {
                        presets[index].category = builtIn.category
                        changed = true
                    }
                    if presets[index].icon != builtIn.icon {
                        presets[index].icon = builtIn.icon
                        changed = true
                    }
                } else {
                    let wasFavorite = presets[index].isFavorite
                    if presets[index] != builtIn || wasFavorite != builtIn.isFavorite {
                        var refreshed = builtIn
                        refreshed.isFavorite = wasFavorite
                        presets[index] = refreshed
                        changed = true
                    }
                }
            } else {
                presets.append(builtIn)
                changed = true
                logger.info("Populated built-in preset: \(builtIn.name, privacy: .public)")
            }
        }
        if changed {
            sortPresets()
            savePresets()
        }
    }

    /// Sorts presets: built-in first (in catalog order), then custom by creation date.
    private func sortPresets() {
        let builtInOrder = PresetCatalog.allBuiltIn.map(\.id)
        presets.sort { a, b in
            if a.isBuiltIn && b.isBuiltIn {
                let indexA = builtInOrder.firstIndex(of: a.id) ?? Int.max
                let indexB = builtInOrder.firstIndex(of: b.id) ?? Int.max
                return indexA < indexB
            }
            if a.isBuiltIn { return true }
            if b.isBuiltIn { return false }
            return a.createdAt < b.createdAt
        }
    }

    // MARK: - Persistence

    private func loadPresets() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data) else {
            presets = []
            return
        }
        presets = decoded
        logger.info("Loaded \(decoded.count) presets")
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else {
            logger.error("Failed to encode presets")
            return
        }
        userDefaults.set(data, forKey: storageKey)
        logger.info("Saved \(self.presets.count) presets")
    }

    private func loadHiddenPresetIDs() {
        guard let ids = userDefaults.array(forKey: hiddenPresetIDsStorageKey) as? [String] else {
            hiddenPresetIDs = []
            return
        }

        hiddenPresetIDs = Set(ids)
        logger.info("Loaded \(ids.count) hidden preset IDs")
    }

    private func saveHiddenPresetIDs() {
        userDefaults.set(Array(hiddenPresetIDs).sorted(), forKey: hiddenPresetIDsStorageKey)
        logger.info("Saved \(self.hiddenPresetIDs.count) hidden preset IDs")
    }

    // MARK: - Helpers

    private func categories(from presets: [Preset]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for preset in presets {
            if !seen.contains(preset.category) {
                seen.insert(preset.category)
                result.append(preset.category)
            }
        }
        return result.sorted { lhs, rhs in
            let lhsIdx = PresetCatalog.categoryOrder.firstIndex(of: lhs) ?? Int.max
            let rhsIdx = PresetCatalog.categoryOrder.firstIndex(of: rhs) ?? Int.max
            if lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
            return lhs < rhs
        }
    }

    private func normalizeForComparison(_ name: String) -> String {
        name.split(separator: /\s+/).joined().lowercased()
    }
}
