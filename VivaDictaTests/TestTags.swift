// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing

extension Tag {
    /// Marks suites that exercise networking through a mocked transport.
    /// No real network calls happen - the tag exists so the suites can be
    /// filtered as a group (e.g. `swift test --filter-tag networking`).
    @Tag static var networking: Self
}
