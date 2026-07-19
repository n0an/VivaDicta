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
    var stubbedLanguageProbabilities: [String: Double]?
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

    func transcribe(audioURL: URL, progressHandler: TranscriptionProgressHandler?) async throws -> TranscriptionServiceResult {
        transcribeCallCount += 1
        return TranscriptionServiceResult(
            text: stubbedText,
            languageProbabilities: stubbedLanguageProbabilities
        )
    }
}
