// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

public extension Color {
    /// Random RGB color in the unit cube. Used by `View.debugBorder()` to
    /// visualize view boundaries during development.
    static func random() -> Color {
        Color(
            red: Double.random(in: 0 ... 1),
            green: Double.random(in: 0 ... 1),
            blue: Double.random(in: 0 ... 1)
        )
    }

    /// Identity helper kept for parity with the legacy API. Returns
    /// `Color(self)`.
    var sui: Color { Color(self) }
}
