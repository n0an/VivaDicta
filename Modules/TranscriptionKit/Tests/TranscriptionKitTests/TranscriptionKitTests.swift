// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import TranscriptionKit

struct TranscriptionEngineTests {

    @Test func unloadingClearsCachedLocalServices() async {
        let engine = TranscriptionEngine()

        let firstWhisper = engine.whisperKit()
        let firstParakeet = engine.parakeet()

        // Re-fetching returns the same cached instance.
        #expect(engine.whisperKit() === firstWhisper)
        #expect(engine.parakeet() === firstParakeet)

        await engine.unloadLocalModels()

        // After unload, the next fetch creates a fresh instance.
        let secondWhisper = engine.whisperKit()
        let secondParakeet = engine.parakeet()
        #expect(secondWhisper !== firstWhisper)
        #expect(secondParakeet !== firstParakeet)
    }
}
