// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AICore
import TranscriptionCore
@testable import VivaDicta

/// Hand-rolled mock of ``Transcriber`` for view-model tests - returns a stubbed
/// transcript without a downloaded/keyed model.
@MainActor
final class MockTranscriber: Transcriber {
    var currentMode: VivaMode
    var stubbedText: String
    /// When set, ``transcribe(audioURL:progressHandler:)`` throws this instead of
    /// returning ``stubbedText`` - the network-drop / unreachable-API case.
    var stubbedError: (any Error)?
    private(set) var setCurrentModeCalls: [VivaMode] = []
    private(set) var transcribeCallCount = 0

    init(currentMode: VivaMode = .defaultMode, stubbedText: String = "stubbed transcript") {
        self.currentMode = currentMode
        self.stubbedText = stubbedText
    }

    func setCurrentMode(_ mode: VivaMode) {
        currentMode = mode
        setCurrentModeCalls.append(mode)
    }

    func getCurrentTranscriptionModel() -> (any TranscriptionModel)? { nil }

    func transcribe(audioURL: URL, progressHandler: TranscriptionProgressHandler?) async throws -> String {
        transcribeCallCount += 1
        if let stubbedError { throw stubbedError }
        return stubbedText
    }

    func transcribe(
        audioURL: URL,
        languageOverride: String?,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> String {
        languageOverrides.append(languageOverride)
        return try await transcribe(audioURL: audioURL, progressHandler: progressHandler)
    }

    /// One entry per override-aware call, `nil` when no override was passed.
    private(set) var languageOverrides: [String?] = []

    func postProcessStreamedText(_ text: String) -> String {
        postProcessStreamedCallCount += 1
        return text
    }

    private(set) var postProcessStreamedCallCount = 0
}
