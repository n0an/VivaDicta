//
//  MockPresetSyncingTests.swift
//  PresetsTests
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing
import Presets
import PresetsMocks

@Suite("MockPresetSyncing contract")
struct MockPresetSyncingTests {

    @Test func tracksCreatePresetRecord() {
        let sut = MockPresetSyncing()
        let preset = PresetCatalog.regular
        sut.createPresetRecord(from: preset)

        #expect(sut.createPresetRecordCallCount == 1)
        #expect(sut.lastCreatedPreset?.id == preset.id)
    }

    @Test func tracksDeletePresetRecord() {
        let sut = MockPresetSyncing()
        sut.deletePresetRecord(presetId: "custom_xyz")

        #expect(sut.deletePresetRecordCallCount == 1)
        #expect(sut.lastDeletedPresetId == "custom_xyz")
    }

    @Test func tracksFavoriteSync() {
        let sut = MockPresetSyncing()
        sut.syncFavoriteState(presetId: "summary", isFavorite: true)

        #expect(sut.syncFavoriteStateCallCount == 1)
        #expect(sut.lastSyncedFavorite?.presetId == "summary")
        #expect(sut.lastSyncedFavorite?.isFavorite == true)
    }

    @Test func didCallbackFiresAfterMutation() {
        let sut = MockPresetSyncing()
        var observedCount: Int?
        sut.didCreatePresetRecord = {
            observedCount = sut.createPresetRecordCallCount
        }
        sut.createPresetRecord(from: PresetCatalog.summary)
        #expect(observedCount == 1)
    }
}
