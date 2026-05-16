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

@Suite("MockPresetSync contract")
struct MockPresetSyncingTests {

    @Test func tracksCreatePresetRecord() {
        let sut = MockPresetSync()
        let preset = PresetCatalog.regular
        sut.createPresetRecord(from: preset)

        #expect(sut.createPresetRecordCallCount == 1)
        #expect(sut.lastCreatedPreset?.id == preset.id)
    }

    @Test func tracksDeletePresetRecord() {
        let sut = MockPresetSync()
        sut.deletePresetRecord(presetId: "custom_xyz")

        #expect(sut.deletePresetRecordCallCount == 1)
        #expect(sut.lastDeletedPresetId == "custom_xyz")
    }

    @Test func tracksFavoriteSync() {
        let sut = MockPresetSync()
        sut.syncFavoriteState(presetId: "summary", isFavorite: true)

        #expect(sut.syncFavoriteStateCallCount == 1)
        #expect(sut.lastSyncedFavorite?.presetId == "summary")
        #expect(sut.lastSyncedFavorite?.isFavorite == true)
    }

    @Test func didCallbackFiresAfterMutation() {
        let sut = MockPresetSync()
        var observedCount: Int?
        sut.didCreatePresetRecord = {
            observedCount = sut.createPresetRecordCallCount
        }
        sut.createPresetRecord(from: PresetCatalog.summary)
        #expect(observedCount == 1)
    }
}
