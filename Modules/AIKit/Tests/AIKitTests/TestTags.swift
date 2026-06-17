// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing

extension Tag {
    /// Marks suites that exercise networking through a mocked transport.
    /// No real network calls happen - the tag exists so the suites can be
    /// selected/excluded as a group (e.g. via an Xcode Test Plan, or
    /// `swift test --filter-tag networking` when running this package alone).
    @Tag static var networking: Self
}
