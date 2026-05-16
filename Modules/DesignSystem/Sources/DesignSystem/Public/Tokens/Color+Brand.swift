// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

/// Semantic color tokens for the VivaDicta brand.
///
/// These are intentionally simple `Color` literals for now - a future PR
/// can promote them to an `Assets.xcassets` color set inside the
/// DesignSystem bundle, with proper light/dark variants. For the moment
/// they centralize the values already scattered through views so call
/// sites stop writing `.orange` / `.red` / `Color(red:...)` inline.
public extension Color {
    /// Primary brand color - used for prominent call-to-action surfaces
    /// (record button, prominent buttons). Currently maps to `.orange`.
    static let vivaAccent: Color = .orange

    /// "Recording in progress" red. The bright, attention-grabbing tone
    /// used to signal an active microphone capture.
    static let vivaRecording: Color = .red

    /// AI-enhancement / sparkle purple. Used for transcription
    /// post-processing UI (sparkles icon, enhancement progress, etc.).
    /// Matches the first stop of `[Gradient.Stop].glowStyle`.
    static let vivaSparkle = Color(
        red: 188 / 255,
        green: 130 / 255,
        blue: 243 / 255
    )

    /// Error / destructive surfaces.
    static let vivaError: Color = .red
}
