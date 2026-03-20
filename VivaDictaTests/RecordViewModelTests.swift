//
//  RecordViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct RecordViewModelTests {

    // MARK: - Audio Level Normalization
    // Tests the formula used in RecordViewModel:
    // min(1, max(0, 1 - abs(Double(averagePower) / 50)))

    private func normalizeAudioPower(_ power: Double) -> Double {
        min(1, max(0, 1 - abs(power / 50)))
    }

    @Test func audioLevelNormalization_negativePower_clamped() {
        // Very quiet audio (-60 dB) → abs(60/50) = 1.2, 1-1.2 = -0.2 → clamped to 0
        let level = normalizeAudioPower(-60)
        #expect(level == 0)
    }

    @Test func audioLevelNormalization_zeroPower_maxLevel() {
        // 0 dB (max volume) → abs(0/50) = 0, 1-0 = 1.0
        let level = normalizeAudioPower(0)
        #expect(level == 1.0)
    }

    @Test func audioLevelNormalization_normalRange() {
        // -25 dB → abs(25/50) = 0.5, 1-0.5 = 0.5
        let level = normalizeAudioPower(-25)
        #expect(level == 0.5)
    }

    // MARK: - Recording State

    @Test func recordingState_initialValue_idle() {
        // RecordingState enum default is .idle
        let state: RecordingState = .idle
        #expect(state == .idle)
    }

    @Test func recordingState_equatable() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.recording == RecordingState.recording)
        #expect(RecordingState.transcribing == RecordingState.transcribing)
        #expect(RecordingState.enhancing == RecordingState.enhancing)
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.error(.avInitError) == RecordingState.error(.avInitError))
        #expect(RecordingState.error(.avInitError) != RecordingState.error(.userDenied))
    }
}
