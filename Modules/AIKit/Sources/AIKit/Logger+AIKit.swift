// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Internal logging convenience for the AIKit module. Methods are
/// intentionally `internal` so they don't collide with the app target's
/// identically named extensions on `Logger`.
extension Logger {
    func logDebug(_ message: String) {
        self.debug("\(message, privacy: .public)")
    }

    func logWarning(_ message: String) {
        self.warning("\(message, privacy: .public)")
    }
}
