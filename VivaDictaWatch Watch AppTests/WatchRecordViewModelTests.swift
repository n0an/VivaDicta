//
//  WatchRecordViewModelTests.swift
//  VivaDictaWatch Watch AppTests
//
//  Created by Anton Novoselov on 2026.04.04
//

import Foundation
import SwiftUI
import Testing
@testable import VivaDictaWatch_Watch_App

@MainActor
struct WatchRecordViewModelTests {

    // MARK: - Test Helpers

    private func makeViewModel(
        connectivityService: MockWatchConnectivityService = MockWatchConnectivityService(),
        audioRecorder: MockWatchAudioRecorder = MockWatchAudioRecorder()
    ) -> (WatchRecordViewModel, MockWatchConnectivityService, MockWatchAudioRecorder, UserDefaults) {
        let suiteName = "WatchRecordViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let vm = WatchRecordViewModel(
            connectivityService: connectivityService,
            audioRecorder: audioRecorder,
            defaults: defaults
        )
        return (vm, connectivityService, audioRecorder, defaults)
    }

    // MARK: - Initialization

    @Test func init_startsIdle() {
        let (vm, _, _, _) = makeViewModel()

        #expect(vm.state == .idle)
        #expect(vm.recordingDuration == 0)
        #expect(vm.selectedModeId == nil)
    }

    @Test func init_restoresSelectedModeFromUserDefaults() {
        let suiteName = "WatchRecordViewModelTests-restore-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("summary", forKey: "selectedWatchModeId")

        let vm = WatchRecordViewModel(
            connectivityService: MockWatchConnectivityService(),
            audioRecorder: MockWatchAudioRecorder(),
            defaults: defaults
        )

        #expect(vm.selectedModeId == "summary")
    }

    // MARK: - Toggle Recording

    @Test func toggleRecording_fromIdle_startsRecording() {
        let (vm, _, recorder, _) = makeViewModel()

        vm.toggleRecording()

        #expect(vm.state == .recording)
        #expect(recorder.startCallCount == 1)
        #expect(recorder.isRecording)
    }

    @Test func toggleRecording_fromRecording_stopsRecording() {
        let (vm, _, recorder, _) = makeViewModel()

        vm.toggleRecording() // start
        vm.toggleRecording() // stop

        #expect(vm.state == .idle)
        #expect(recorder.stopCallCount == 1)
        #expect(recorder.isRecording == false)
    }

    @Test func toggleRecording_startFailure_remainsIdle() {
        let recorder = MockWatchAudioRecorder()
        recorder.shouldThrowOnStart = true
        let (vm, _, _, _) = makeViewModel(audioRecorder: recorder)

        vm.toggleRecording()

        #expect(vm.state == .idle)
        #expect(recorder.startCallCount == 1)
    }

    // MARK: - File Transfer

    @Test func stopRecording_queuesFileTransfer() {
        let (vm, connectivity, _, _) = makeViewModel()

        vm.toggleRecording()
        vm.toggleRecording()

        #expect(connectivity.transferredFiles.count == 1)
    }

    @Test func stopRecording_includesSourceTagInMetadata() throws {
        let (vm, connectivity, _, _) = makeViewModel()

        vm.toggleRecording()
        vm.toggleRecording()

        let metadata = try #require(connectivity.transferredFiles.first?.metadata)
        #expect(metadata["sourceTag"] as? String == "appleWatch")
    }

    @Test func stopRecording_includesTimestampInMetadata() throws {
        let (vm, connectivity, _, _) = makeViewModel()
        let beforeTime = Date().timeIntervalSince1970

        vm.toggleRecording()
        vm.toggleRecording()

        let timestamp = try #require(connectivity.transferredFiles.first?.metadata["timestamp"] as? TimeInterval)
        #expect(timestamp >= beforeTime)
    }

    @Test func stopRecording_includesDurationInMetadata() throws {
        let (vm, connectivity, _, _) = makeViewModel()

        vm.toggleRecording()
        vm.toggleRecording()

        _ = try #require(connectivity.transferredFiles.first?.metadata["duration"] as? TimeInterval)
    }

    @Test func stopRecording_includesModeIdWhenSelected() throws {
        let (vm, connectivity, _, _) = makeViewModel()
        vm.selectedModeId = "professional"

        vm.toggleRecording()
        vm.toggleRecording()

        let metadata = try #require(connectivity.transferredFiles.first?.metadata)
        #expect(metadata["modeId"] as? String == "professional")
    }

    @Test func stopRecording_omitsModeIdWhenNil() throws {
        let (vm, connectivity, _, _) = makeViewModel()
        vm.selectedModeId = nil

        vm.toggleRecording()
        vm.toggleRecording()

        let metadata = try #require(connectivity.transferredFiles.first?.metadata)
        #expect(metadata["modeId"] == nil)
    }

    @Test func stopRecording_transferFailure_stillResetsState() {
        let connectivity = MockWatchConnectivityService()
        connectivity.shouldSucceedTransfer = false
        let (vm, _, _, _) = makeViewModel(connectivityService: connectivity)

        vm.toggleRecording()
        vm.toggleRecording()

        #expect(vm.state == .idle)
        #expect(vm.recordingDuration == 0)
    }

    // MARK: - Transfer Status Passthrough

    @Test func transferStatus_reflectsConnectivityService() {
        let connectivity = MockWatchConnectivityService()
        connectivity.transferStatus = .transferring(count: 2)
        let (vm, _, _, _) = makeViewModel(connectivityService: connectivity)

        #expect(vm.transferStatus == .transferring(count: 2))
    }

    @Test func pendingCount_reflectsConnectivityService() {
        let connectivity = MockWatchConnectivityService()
        connectivity.pendingTransferCount = 3
        let (vm, _, _, _) = makeViewModel(connectivityService: connectivity)

        #expect(vm.pendingCount == 3)
    }

    // MARK: - Available Modes Passthrough

    @Test func availableModes_reflectsConnectivityService() {
        let connectivity = MockWatchConnectivityService()
        connectivity.availableModes = [
            WatchModeInfo(id: "regular", name: "Regular"),
            WatchModeInfo(id: "summary", name: "Summary")
        ]
        let (vm, _, _, _) = makeViewModel(connectivityService: connectivity)

        #expect(vm.availableModes.count == 2)
        #expect(vm.availableModes[0].id == "regular")
    }

    // MARK: - Mode Selection Persistence

    @Test func selectedModeId_persistsToUserDefaults() {
        let (vm, _, _, defaults) = makeViewModel()

        vm.selectedModeId = "email"

        let stored = defaults.string(forKey: "selectedWatchModeId")
        #expect(stored == "email")
    }

    // MARK: - Recording Duration

    @Test func recordingDuration_resetsOnStop() {
        let (vm, _, _, _) = makeViewModel()

        vm.toggleRecording()
        // Duration starts at 0, timer increments it
        vm.toggleRecording()

        #expect(vm.recordingDuration == 0)
    }

    // MARK: - Scene Phase Handling

    @Test func scenePhaseBackground_whileRecording_stopsRecording() {
        let (vm, connectivity, _, _) = makeViewModel()

        vm.toggleRecording()
        #expect(vm.state == .recording)

        vm.handleScenePhaseChange(to: .background)

        #expect(vm.state == .idle)
        #expect(connectivity.transferredFiles.count == 1)
    }

    @Test func scenePhaseInactive_whileRecording_continuesRecording() {
        let (vm, _, _, _) = makeViewModel()

        vm.toggleRecording()
        #expect(vm.state == .recording)

        vm.handleScenePhaseChange(to: .inactive)

        #expect(vm.state == .recording)
    }

    @Test func scenePhaseBackground_whileIdle_doesNothing() {
        let (vm, connectivity, _, _) = makeViewModel()

        vm.handleScenePhaseChange(to: .background)

        #expect(vm.state == .idle)
        #expect(connectivity.transferredFiles.isEmpty)
    }

    @Test func scenePhaseActive_whileRecording_doesNotStop() {
        let (vm, _, _, _) = makeViewModel()

        vm.toggleRecording()
        #expect(vm.state == .recording)

        vm.handleScenePhaseChange(to: .active)

        #expect(vm.state == .recording)
    }

    // MARK: - Multiple Record/Stop Cycles

    @Test func multipleRecordStopCycles_workCorrectly() {
        let (vm, connectivity, recorder, _) = makeViewModel()

        // First cycle
        vm.toggleRecording()
        #expect(vm.state == .recording)
        vm.toggleRecording()
        #expect(vm.state == .idle)

        // Second cycle
        vm.toggleRecording()
        #expect(vm.state == .recording)
        vm.toggleRecording()
        #expect(vm.state == .idle)

        #expect(recorder.startCallCount == 2)
        #expect(recorder.stopCallCount == 2)
        #expect(connectivity.transferredFiles.count == 2)
    }

    @Test func stopRecording_whenNotRecording_doesNotTransfer() {
        let recorder = MockWatchAudioRecorder()
        recorder.shouldThrowOnStart = true
        let (vm, connectivity, _, _) = makeViewModel(audioRecorder: recorder)

        vm.toggleRecording() // fails to start
        #expect(vm.state == .idle)
        #expect(connectivity.transferredFiles.isEmpty)
    }
}
