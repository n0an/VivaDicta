//
//  MockPresetSyncing.swift
//  PresetsMocks
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Presets

/// Hand-rolled mock for `PresetSyncing`. Tracks call counts and the records
/// the production code under test wrote, but does not actually persist
/// anything. Each method also exposes an after-side-effect callback so tests
/// can fulfill expectations only after the production code has finished
/// touching the mock.
public final class MockPresetSyncing: PresetSyncing, @unchecked Sendable {

    public init() {}

    // Call tracking
    public var createPresetRecordCallCount = 0
    public var updatePresetRecordCallCount = 0
    public var deletePresetRecordCallCount = 0
    public var syncBuiltInPresetRecordCallCount = 0
    public var resetBuiltInPresetRecordCallCount = 0
    public var syncFavoriteStateCallCount = 0

    // Last argument captured per method
    public var lastCreatedPreset: Preset?
    public var lastUpdatedPreset: Preset?
    public var lastDeletedPresetId: String?
    public var lastSyncedBuiltInPreset: Preset?
    public var lastResetBuiltInPresetId: String?
    public var lastSyncedFavorite: (presetId: String, isFavorite: Bool)?

    // After-side-effect callbacks
    public var didCreatePresetRecord: (() -> Void)?
    public var didUpdatePresetRecord: (() -> Void)?
    public var didDeletePresetRecord: (() -> Void)?
    public var didSyncBuiltInPresetRecord: (() -> Void)?
    public var didResetBuiltInPresetRecord: (() -> Void)?
    public var didSyncFavoriteState: (() -> Void)?

    public func createPresetRecord(from preset: Preset) {
        defer { didCreatePresetRecord?() }
        createPresetRecordCallCount += 1
        lastCreatedPreset = preset
    }

    public func updatePresetRecord(from preset: Preset) {
        defer { didUpdatePresetRecord?() }
        updatePresetRecordCallCount += 1
        lastUpdatedPreset = preset
    }

    public func deletePresetRecord(presetId: String) {
        defer { didDeletePresetRecord?() }
        deletePresetRecordCallCount += 1
        lastDeletedPresetId = presetId
    }

    public func syncBuiltInPresetRecord(from preset: Preset) {
        defer { didSyncBuiltInPresetRecord?() }
        syncBuiltInPresetRecordCallCount += 1
        lastSyncedBuiltInPreset = preset
    }

    public func resetBuiltInPresetRecord(presetId: String) {
        defer { didResetBuiltInPresetRecord?() }
        resetBuiltInPresetRecordCallCount += 1
        lastResetBuiltInPresetId = presetId
    }

    public func syncFavoriteState(presetId: String, isFavorite: Bool) {
        defer { didSyncFavoriteState?() }
        syncFavoriteStateCallCount += 1
        lastSyncedFavorite = (presetId, isFavorite)
    }
}
