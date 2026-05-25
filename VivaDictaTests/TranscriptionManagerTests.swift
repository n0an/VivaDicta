//
//  TranscriptionManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import Testing
import TranscriptionCore
import TranscriptionKitMocks
@testable import VivaDicta

/// First app-target test class importing a module Mocks library
/// (`TranscriptionKitMocks`) to inject a `MockTranscriptionEngine` into
/// `TranscriptionManager` through the `any TranscriptionEngine` protocol.
///
/// Coverage is intentionally narrow: the manager reads several singletons
/// directly (`UserDefaultsStorage.shared`, `AppGroupCoordinator.shared`,
/// `CustomTranscriptionModelManager.shared`) so end-to-end pipeline tests
/// are out of scope until those are DI'd as well. These tests prove the
/// protocol-DI wire and exercise the control-flow branches that don't
/// touch app-wide state.
@MainActor
struct TranscriptionManagerTests {

    let mockEngine: MockTranscriptionEngine
    let sut: TranscriptionManager

    init() {
        mockEngine = MockTranscriptionEngine()
        sut = TranscriptionManager(engine: mockEngine)
    }

    private func makeMode(
        provider: TranscriptionModelProvider,
        model: String
    ) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "TestMode",
            transcriptionProvider: provider,
            transcriptionModel: model,
            aiModel: "",
            aiEnhanceEnabled: false
        )
    }

    // MARK: - preloadWhisperKitModelIfNeeded

    @Test func preloadWhisperKitModelIfNeeded_doesNothing_whenCurrentModeIsParakeet() async {
        sut.setCurrentMode(makeMode(provider: .parakeet, model: "parakeet-tdt-0.6b-v3"))

        await sut.preloadWhisperKitModelIfNeeded()

        #expect(mockEngine.preloadWhisperKitModelCallCount == 0)
    }

    @Test func preloadWhisperKitModelIfNeeded_doesNothing_whenCurrentModeIsCloudProvider() async {
        sut.setCurrentMode(makeMode(provider: .openAI, model: "whisper-1"))

        await sut.preloadWhisperKitModelIfNeeded()

        #expect(mockEngine.preloadWhisperKitModelCallCount == 0)
    }

    // MARK: - transcribe error path

    @Test func transcribe_throws_andDoesNotInvokeEngine_whenCurrentModelIsUnknown() async {
        sut.setCurrentMode(makeMode(provider: .whisperKit, model: "nonexistent-model-xyz"))

        let url = URL(fileURLWithPath: "/tmp/x.wav")
        await #expect(throws: TranscriptionError.self) {
            _ = try await sut.transcribe(audioURL: url)
        }
        #expect(mockEngine.transcribeCallCount == 0)
    }

    // MARK: - setCurrentMode

    @Test func setCurrentMode_updatesCurrentMode() {
        let mode = makeMode(provider: .parakeet, model: "parakeet-tdt-0.6b-v3")

        sut.setCurrentMode(mode)

        #expect(sut.currentMode.id == mode.id)
    }
}
