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
}
