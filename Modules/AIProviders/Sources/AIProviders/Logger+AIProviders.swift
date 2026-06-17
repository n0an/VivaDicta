// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Internal logging convenience for the AIProviders module. Methods are
/// intentionally `internal` so they don't collide with the app target's
/// identically named extensions on `Logger`.
extension Logger {
    func logInfo(_ message: String) {
        self.info("\(message, privacy: .public)")
    }

    func logWarning(_ message: String) {
        self.warning("\(message, privacy: .public)")
    }

    func logError(_ message: String) {
        self.error("\(message, privacy: .public)")
    }

    func logNotice(_ message: String) {
        self.notice("\(message, privacy: .public)")
    }
}
