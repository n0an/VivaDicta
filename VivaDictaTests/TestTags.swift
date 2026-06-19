// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing

extension Tag {
    /// Marks suites that exercise networking through a mocked transport.
    /// No real network calls happen - the tag exists so the suites can be
    /// selected/excluded as a group from an Xcode Test Plan.
    @Tag static var networking: Self

    /// Marks suites that touch the filesystem (audio files, exports, temp
    /// directories). Selectable so a slow CI tier can run them separately.
    @Tag static var cleanup: Self

    /// Marks suites that build a real SwiftData `ModelContainer`. Heavier than
    /// pure-value tests, lighter than full integration runs.
    @Tag static var database: Self

    /// Marks integration suites: real collaborators (a real in-memory SwiftData
    /// store, real file IO), happy path, asserting persistence across contexts.
    @Tag static var integration: Self

    /// Marks acceptance suites: a composed flow driven through its public seams,
    /// with test doubles only at the system boundary (network, transcription
    /// engine), against a real in-memory store.
    @Tag static var acceptance: Self
}
