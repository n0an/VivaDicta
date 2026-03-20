//
//  AppGroupCoordinatorStateTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct AppGroupCoordinatorStateTests {

    // MARK: - Test Helpers

    private let suiteName = "AppGroupCoordinatorStateTests.\(UUID().uuidString)"

    private func makeCoordinator() -> AppGroupCoordinator {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppGroupCoordinator(userDefaults: defaults)
    }

    // MARK: - Audio Level Tests

    @Test func audioLevel_clampsNegativeToZero() {
        let coordinator = makeCoordinator()

        coordinator.updateAudioLevel(-0.5)

        #expect(coordinator.currentAudioLevel == 0.0)
    }

    @Test func audioLevel_clampsAboveOneToOne() {
        let coordinator = makeCoordinator()

        coordinator.updateAudioLevel(1.5)

        #expect(coordinator.currentAudioLevel == 1.0)
    }

    @Test func audioLevel_normalValueStored() {
        let coordinator = makeCoordinator()

        coordinator.updateAudioLevel(0.7)

        #expect(abs(coordinator.currentAudioLevel - 0.7) < 0.001)
    }

    @Test func audioLevel_defaultIsZero() {
        let coordinator = makeCoordinator()

        #expect(coordinator.currentAudioLevel == 0.0)
    }

    // MARK: - Transcription Status Tests

    @Test func transcriptionStatus_roundTrips() {
        let coordinator = makeCoordinator()
        let statuses: [AppGroupCoordinator.TranscriptionStatus] = [
            .idle, .recording, .transcribing, .enhancing, .completed, .error
        ]

        for status in statuses {
            coordinator.updateTranscriptionStatus(status)
            #expect(coordinator.transcriptionStatus == status)
        }
    }

    @Test func transcriptionStatus_defaultIsIdle() {
        let coordinator = makeCoordinator()

        #expect(coordinator.transcriptionStatus == .idle)
    }

    @Test func transcriptionStatus_invalidString_returnsIdle() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("garbage_status", forKey: "transcriptionStatus")
        let coordinator = AppGroupCoordinator(userDefaults: defaults)

        #expect(coordinator.transcriptionStatus == .idle)
    }

    // MARK: - Recording State Tests

    @Test func recordingState_setAndGet() {
        let coordinator = makeCoordinator()

        coordinator.updateRecordingState(true)
        #expect(coordinator.isRecording == true)

        coordinator.updateRecordingState(false)
        #expect(coordinator.isRecording == false)
    }

    // MARK: - Transcribed Text Sharing Tests

    @Test func shareTranscribedText_storesAndSetsCompleted() {
        let coordinator = makeCoordinator()

        coordinator.shareTranscribedText("Hello world")

        #expect(coordinator.transcriptionStatus == .completed)
    }

    @Test func getAndConsumeTranscribedText_retrievesAndClears() {
        let coordinator = makeCoordinator()
        coordinator.shareTranscribedText("Test text")

        let text = coordinator.getAndConsumeTranscribedText()
        let textAgain = coordinator.getAndConsumeTranscribedText()

        #expect(text == "Test text")
        #expect(textAgain == nil)
    }

    @Test func getAndConsumeTranscribedText_setsStatusIdle() {
        let coordinator = makeCoordinator()
        coordinator.shareTranscribedText("Test text")

        _ = coordinator.getAndConsumeTranscribedText()

        #expect(coordinator.transcriptionStatus == .idle)
    }

    // MARK: - Clipboard Context Tests

    @Test func getAndConsumeClipboardContext_retrievesAndClears() {
        let coordinator = makeCoordinator()
        coordinator.setKeyboardClipboardContext("clipboard content")

        let text = coordinator.getAndConsumeKeyboardClipboardContext()
        let textAgain = coordinator.getAndConsumeKeyboardClipboardContext()

        #expect(text == "clipboard content")
        #expect(textAgain == nil)
    }

    @Test func setKeyboardClipboardContext_nil_clears() {
        let coordinator = makeCoordinator()
        coordinator.setKeyboardClipboardContext("something")
        coordinator.setKeyboardClipboardContext(nil)

        let text = coordinator.getAndConsumeKeyboardClipboardContext()
        #expect(text == nil)
    }
}
