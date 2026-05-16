//
//  AppGroupCoordinatorStateTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import AppGroup

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
        let sut = makeCoordinator()

        sut.updateAudioLevel(-0.5)

        #expect(sut.currentAudioLevel == 0.0)
    }

    @Test func audioLevel_clampsAboveOneToOne() {
        let sut = makeCoordinator()

        sut.updateAudioLevel(1.5)

        #expect(sut.currentAudioLevel == 1.0)
    }

    @Test func audioLevel_normalValueStored() {
        let sut = makeCoordinator()

        sut.updateAudioLevel(0.7)

        #expect(abs(sut.currentAudioLevel - 0.7) < 0.001)
    }

    @Test func audioLevel_defaultIsZero() {
        let sut = makeCoordinator()

        #expect(sut.currentAudioLevel == 0.0)
    }

    // MARK: - Transcription Status Tests

    @Test func transcriptionStatus_roundTrips() {
        let sut = makeCoordinator()
        let statuses: [AppGroupCoordinator.TranscriptionStatus] = [
            .idle, .recording, .transcribing, .enhancing, .completed, .error
        ]

        for status in statuses {
            sut.updateTranscriptionStatus(status)
            #expect(sut.transcriptionStatus == status)
        }
    }

    @Test func transcriptionStatus_defaultIsIdle() {
        let sut = makeCoordinator()

        #expect(sut.transcriptionStatus == .idle)
    }

    @Test func transcriptionStatus_invalidString_returnsIdle() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("garbage_status", forKey: "transcriptionStatus")
        let sut = AppGroupCoordinator(userDefaults: defaults)

        #expect(sut.transcriptionStatus == .idle)
    }

    // MARK: - Recording State Tests

    @Test func recordingState_setAndGet() {
        let sut = makeCoordinator()

        sut.updateRecordingState(true)
        #expect(sut.isRecording == true)

        sut.updateRecordingState(false)
        #expect(sut.isRecording == false)
    }

    // MARK: - Transcribed Text Sharing Tests

    @Test func shareTranscribedText_storesAndSetsCompleted() {
        let sut = makeCoordinator()

        sut.shareTranscribedText("Hello world")

        #expect(sut.transcriptionStatus == .completed)
    }

    @Test func getAndConsumeTranscribedText_retrievesAndClears() {
        let sut = makeCoordinator()
        sut.shareTranscribedText("Test text")

        let text = sut.getAndConsumeTranscribedText()
        let textAgain = sut.getAndConsumeTranscribedText()

        #expect(text == "Test text")
        #expect(textAgain == nil)
    }

    @Test func getAndConsumeTranscribedText_setsStatusIdle() {
        let sut = makeCoordinator()
        sut.shareTranscribedText("Test text")

        _ = sut.getAndConsumeTranscribedText()

        #expect(sut.transcriptionStatus == .idle)
    }

    // MARK: - Clipboard Context Tests

    @Test func getAndConsumeClipboardContext_retrievesAndClears() {
        let sut = makeCoordinator()
        sut.setKeyboardClipboardContext("clipboard content")

        let text = sut.getAndConsumeKeyboardClipboardContext()
        let textAgain = sut.getAndConsumeKeyboardClipboardContext()

        #expect(text == "clipboard content")
        #expect(textAgain == nil)
    }

    @Test func setKeyboardClipboardContext_nil_clears() {
        let sut = makeCoordinator()
        sut.setKeyboardClipboardContext("something")
        sut.setKeyboardClipboardContext(nil)

        let text = sut.getAndConsumeKeyboardClipboardContext()
        #expect(text == nil)
    }
}
