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
/// Coverage is intentionally narrow: the manager still reads a couple of
/// singletons directly (`UserDefaultsStorage.shared`, `AppGroupCoordinator.shared`)
/// so end-to-end pipeline tests are out of scope until those are DI'd as well.
/// The custom-transcription source is now injected (see `FakeCustomSource`),
/// so `hasAvailableTranscriptionModels` and the custom-model path of
/// `getCurrentTranscriptionModel` are testable.
@MainActor
struct TranscriptionManagerTests {

    let mockEngine: MockTranscriptionEngine
    let customSource: FakeCustomSource
    let sut: TranscriptionManager

    init() {
        mockEngine = MockTranscriptionEngine()
        customSource = FakeCustomSource()
        sut = TranscriptionManager(
            engine: mockEngine,
            customTranscriptionSource: customSource
        )
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

    // MARK: - Custom transcription source injection

    @Test func hasAvailableTranscriptionModels_isTrue_whenOnlyCustomSourceIsConfigured() {
        customSource.isConfigured = true
        customSource.configuredModel = Self.makeCustomModel()

        #expect(sut.hasAvailableTranscriptionModels)
    }

    @Test func getCurrentTranscriptionModel_returnsCustomModel_whenSourceConfigured() {
        let model = Self.makeCustomModel()
        customSource.isConfigured = true
        customSource.configuredModel = model
        sut.setCurrentMode(makeMode(provider: .customTranscription, model: "custom"))

        let result = sut.getCurrentTranscriptionModel()

        #expect((result as? CustomTranscriptionModel)?.id == model.id)
    }

    @Test func getCurrentTranscriptionModel_returnsNil_whenCustomSourceUnconfigured() {
        customSource.isConfigured = false
        customSource.configuredModel = nil
        sut.setCurrentMode(makeMode(provider: .customTranscription, model: "custom"))

        #expect(sut.getCurrentTranscriptionModel() == nil)
    }

    private static func makeCustomModel() -> CustomTranscriptionModel {
        CustomTranscriptionModel(
            id: UUID(),
            name: "custom",
            displayName: "Custom",
            apiEndpoint: "https://example.com/v1",
            modelName: "test-model",
            isMultilingual: true
        )
    }
}

@MainActor
final class FakeCustomSource: CustomTranscriptionModelSource {
    var isConfigured: Bool = false
    var configuredModel: CustomTranscriptionModel? = nil
}
