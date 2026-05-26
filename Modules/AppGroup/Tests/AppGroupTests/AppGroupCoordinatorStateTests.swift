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

    private let suiteName = "AppGroupCoordinatorStateTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let sut: AppGroupCoordinator

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        sut = AppGroupCoordinator(userDefaults: defaults)
    }

    // MARK: - Audio Level Tests

    @Test func audioLevel_clampsNegativeToZero() {
        sut.updateAudioLevel(-0.5)

        #expect(sut.currentAudioLevel == 0.0)
    }

    @Test func audioLevel_clampsAboveOneToOne() {
        sut.updateAudioLevel(1.5)

        #expect(sut.currentAudioLevel == 1.0)
    }

    @Test func audioLevel_normalValueStored() {
        sut.updateAudioLevel(0.7)

        #expect(abs(sut.currentAudioLevel - 0.7) < 0.001)
    }

    @Test func audioLevel_defaultIsZero() {
        #expect(sut.currentAudioLevel == 0.0)
    }

    // MARK: - Transcription Status Tests

    @Test func transcriptionStatus_roundTrips() {
        let statuses: [AppGroupCoordinator.TranscriptionStatus] = [
            .idle, .recording, .transcribing, .enhancing, .completed, .error
        ]

        for status in statuses {
            sut.updateTranscriptionStatus(status)
            #expect(sut.transcriptionStatus == status)
        }
    }

    @Test func transcriptionStatus_defaultIsIdle() {
        #expect(sut.transcriptionStatus == .idle)
    }

    @Test func transcriptionStatus_invalidString_returnsIdle() {
        // Pre-seed a garbage value, then build a fresh coordinator that has
        // to read it at construction time. Shadows the hoisted `sut`
        // intentionally so initial-read behaviour is exercised.
        defaults.set("garbage_status", forKey: "transcriptionStatus")
        let sut = AppGroupCoordinator(userDefaults: defaults)

        #expect(sut.transcriptionStatus == .idle)
    }

    // MARK: - Recording State Tests

    @Test func recordingState_setAndGet() {
        sut.updateRecordingState(true)
        #expect(sut.isRecording == true)

        sut.updateRecordingState(false)
        #expect(sut.isRecording == false)
    }

    // MARK: - Transcribed Text Sharing Tests

    @Test func shareTranscribedText_storesAndSetsCompleted() {
        sut.shareTranscribedText("Hello world")

        #expect(sut.transcriptionStatus == .completed)
    }

    @Test func getAndConsumeTranscribedText_retrievesAndClears() {
        sut.shareTranscribedText("Test text")

        let text = sut.getAndConsumeTranscribedText()
        let textAgain = sut.getAndConsumeTranscribedText()

        #expect(text == "Test text")
        #expect(textAgain == nil)
    }

    @Test func getAndConsumeTranscribedText_setsStatusIdle() {
        sut.shareTranscribedText("Test text")

        _ = sut.getAndConsumeTranscribedText()

        #expect(sut.transcriptionStatus == .idle)
    }

    // MARK: - Clipboard Context Tests

    @Test func getAndConsumeClipboardContext_retrievesAndClears() {
        sut.setKeyboardClipboardContext("clipboard content")

        let text = sut.getAndConsumeKeyboardClipboardContext()
        let textAgain = sut.getAndConsumeKeyboardClipboardContext()

        #expect(text == "clipboard content")
        #expect(textAgain == nil)
    }

    @Test func setKeyboardClipboardContext_nil_clears() {
        sut.setKeyboardClipboardContext("something")
        sut.setKeyboardClipboardContext(nil)

        let text = sut.getAndConsumeKeyboardClipboardContext()
        #expect(text == nil)
    }
}
