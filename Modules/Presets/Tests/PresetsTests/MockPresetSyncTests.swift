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
    
    var sut: MockPresetSync
    
    init() {
        self.sut = MockPresetSync()
    }

    @Test func tracksCreatePresetRecord() {
        let preset = PresetCatalog.regular
        sut.createPresetRecord(from: preset)

        #expect(sut.createPresetRecordCallCount == 1)
        #expect(sut.lastCreatedPreset?.id == preset.id)
    }

    @Test func tracksDeletePresetRecord() {
        sut.deletePresetRecord(presetId: "custom_xyz")

        #expect(sut.deletePresetRecordCallCount == 1)
        #expect(sut.lastDeletedPresetId == "custom_xyz")
    }

    @Test func tracksFavoriteSync() {
        sut.syncFavoriteState(presetId: "summary", isFavorite: true)

        #expect(sut.syncFavoriteStateCallCount == 1)
        #expect(sut.lastSyncedFavorite?.presetId == "summary")
        #expect(sut.lastSyncedFavorite?.isFavorite == true)
    }

    @Test func didCallbackFiresAfterMutation() {
        var observedCount: Int?
        sut.didCreatePresetRecord = {
            observedCount = sut.createPresetRecordCallCount
        }
        sut.createPresetRecord(from: PresetCatalog.summary)
        #expect(observedCount == 1)
    }
}
