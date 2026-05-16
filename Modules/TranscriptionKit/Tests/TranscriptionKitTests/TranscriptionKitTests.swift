// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import TranscriptionKit

struct TranscriptionEngineTests {

    /// `unloadLocalModels()` is idempotent and safe to call on a freshly
    /// constructed engine. Smoke test that hits the actor methods without
    /// touching real models.
    @Test func unloadOnFreshEngineDoesNotThrow() async {
        let engine = TranscriptionEngine()
        await engine.unloadLocalModels()
        // Second call should also be a no-op.
        await engine.unloadLocalModels()
    }
}
