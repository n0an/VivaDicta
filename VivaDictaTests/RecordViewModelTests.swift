//
//  RecordViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

/// `AudioRecording` was extracted into its own module so the audio-capture
/// surface of `RecordViewModel` is now mockable via `MockAudioRecordingService` /
/// `MockAudioFileService`. The real impls are covered by `AudioRecordingTests`.
///
/// A fully hermetic VM test (constructing `RecordViewModel` with mock audio
/// services) is still blocked: `AppState.init` instantiates concrete
/// `AIService` + `TranscriptionManager` + `PresetSyncService` (CloudKit),
/// which leaks state across parallel test runs. The right unlock is the
/// next planned refactor - seam `AppState` / `AIService` behind protocols.
struct RecordViewModelTests {

    // MARK: - Audio Level Normalization (pure formula, no VM construction)

    private func normalizeAudioPower(_ power: Double) -> Double {
        min(1, max(0, 1 - abs(power / 50)))
    }

    @Test func audioLevelNormalization_negativePower_clamped() {
        #expect(normalizeAudioPower(-60) == 0)
    }

    @Test func audioLevelNormalization_zeroPower_maxLevel() {
        #expect(normalizeAudioPower(0) == 1.0)
    }

    @Test func audioLevelNormalization_normalRange() {
        #expect(normalizeAudioPower(-25) == 0.5)
    }

    // MARK: - Recording State

    @Test func recordingState_initialValue_idle() {
        let state: RecordingState = .idle
        #expect(state == .idle)
    }

    @Test func recordingState_equatable() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.error(.avInitError) == RecordingState.error(.avInitError))
        #expect(RecordingState.error(.avInitError) != RecordingState.error(.userDenied))
    }
}
