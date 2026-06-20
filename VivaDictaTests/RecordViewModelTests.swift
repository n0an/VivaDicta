//
//  RecordViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import SwiftData
import Testing
import AICore
@testable import VivaDicta

/// `RecordViewModel` is now constructible in a test: its AI, transcription,
/// audio, and app-group surfaces are seamed behind protocols
/// (`AIProcessingService` / `Transcriber` / `AudioPrewarmer` / `AppGroupBridge`),
/// so a test injects mocks for all of them. `AppState` stays a real instance -
/// its init boots the service graph, but that is fast and non-fatal under test
/// (the only noise is CloudKit's "no iCloud account"), so no `AppState` seam was
/// needed. The pure-formula tests below predate the seams; the construction test
/// exercises the seamed VM.
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

    // MARK: - Construction (now that AI / transcription / audio / app-group are seamed)

    /// Constructs the real `RecordViewModel` with every injected dependency mocked.
    /// `AppState` is still a real instance (its god-object init boots the service
    /// graph), but the four seams mean the VM's own AI/transcription/audio/app-group
    /// surfaces are mock-driven, and the keyboard handlers wire onto the injected
    /// bridge instead of the process-global singleton.
    @MainActor
    @Test func constructsWithMocks_andWiresKeyboardHandlersOntoInjectedBridge() throws {
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let appGroup = MockAppGroupBridge()
        let sut = RecordViewModel(
            appState: AppState(),
            modelContainer: container,
            transcriptionManager: MockTranscriber(),
            aiService: MockAIProcessingService(),
            prewarmManager: MockAudioPrewarmer(),
            appGroupBridge: appGroup
        )

        #expect(sut.recordingState == .idle)
        // Proof the AppGroupBridge seam is effective: setup wired the keyboard
        // control callbacks onto the injected mock, not AppGroupCoordinator.shared.
        #expect(appGroup.onStartRecordingRequested != nil)
        #expect(appGroup.onStopRecordingRequested != nil)
    }
}
