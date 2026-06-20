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
import AppGroup
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

    // MARK: - transcribeSpeechTask flow

    @MainActor
    private func makeSUT(
        transcriber: MockTranscriber,
        aiService: MockAIProcessingService = MockAIProcessingService(),
        appGroup: MockAppGroupBridge = MockAppGroupBridge()
    ) throws -> (sut: RecordViewModel, container: ModelContainer) {
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let sut = RecordViewModel(
            appState: AppState(),
            modelContainer: container,
            transcriptionManager: transcriber,
            aiService: aiService,
            prewarmManager: MockAudioPrewarmer(),
            appGroupBridge: appGroup
        )
        return (sut, container)
    }

    /// Parakeet provider so `transcribeSpeechTask` skips the real-audio
    /// downsampling path and goes straight to the mocked `transcribe`.
    private func parakeetMode() -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "Parakeet",
            transcriptionProvider: .parakeet,
            transcriptionModel: "parakeet",
            aiProvider: .openAI,
            aiModel: "gpt-4",
            aiEnhanceEnabled: true
        )
    }

    private func makeDummyAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    @MainActor
    @Test func transcribeSpeechTask_transcribesAndEnhances_persistsAndPushesStatus() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "hello world")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = true
        ai.stubEnhanceResult = .success(("HELLO WORLD enhanced", 0.1, "TestPrompt"))
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(transcriber.transcribeCallCount == 1)
        #expect(ai.enhanceCallCount == 1)
        #expect(appGroup.transcriptionStatuses.contains(.transcribing))
        #expect(appGroup.transcriptionStatuses.contains(.enhancing))

        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        #expect(saved.first?.text == "hello world")
        #expect(saved.first?.enhancedText == "HELLO WORLD enhanced")
    }

    @MainActor
    @Test func transcribeSpeechTask_whenNotConfigured_persistsTranscriptWithoutEnhancing() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "just a note")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = false // -> shouldEnhance is false
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(transcriber.transcribeCallCount == 1)
        #expect(ai.enhanceCallCount == 0)
        #expect(appGroup.transcriptionStatuses.contains(.transcribing))
        #expect(!appGroup.transcriptionStatuses.contains(.enhancing))

        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        #expect(saved.first?.text == "just a note")
        #expect(saved.first?.enhancedText == nil)
    }

    private enum FlowTestError: Error { case boom }

    @MainActor
    @Test func transcribeSpeechTask_whenEnhancementFails_persistsTranscriptAndAlerts() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "kept transcript")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = true
        ai.stubEnhanceResult = .failure(FlowTestError.boom)
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(ai.enhanceCallCount == 1)
        // Enhancement failed, but the transcript is still saved (text only) and the
        // user is alerted.
        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        #expect(saved.first?.text == "kept transcript")
        #expect(saved.first?.enhancedText == nil)
        #expect(sut.isShowingAlert == true)
    }

    @MainActor
    @Test func transcribeSpeechTask_whenTranscriptHasNoMeaningfulContent_doesNotPersist() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "   ")
        let ai = MockAIProcessingService()
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(transcriber.transcribeCallCount == 1)
        #expect(ai.enhanceCallCount == 0) // skipped - no meaningful content
        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.isEmpty)
        #expect(sut.recordingState == .idle)
        #expect(appGroup.transcriptionStatuses.contains(.idle))
    }
}
