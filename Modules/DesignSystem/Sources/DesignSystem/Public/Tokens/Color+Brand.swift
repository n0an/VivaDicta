// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

/// Semantic color tokens for the VivaDicta brand.
///
/// These are intentionally simple `Color` literals for now - a future PR
/// can promote them to an `Assets.xcassets` color set inside the
/// DesignSystem bundle, with proper light/dark variants. For the moment
/// they centralize the values already scattered through views; new code
/// should reach for these instead of inline `.orange` / `.red` / `Color(red:...)`.
public extension Color {
    /// Primary brand color - used for prominent call-to-action surfaces
    /// (record button, prominent buttons). Currently maps to `.orange`.
    static let vivaAccent: Color = .orange

    /// "Recording in progress" red. The bright, attention-grabbing tone
    /// used to signal an active microphone capture.
    /// Intentionally a separate token from `vivaError` even though both
    /// currently resolve to `.red` - the two are semantically distinct
    /// and may diverge once the palette is finalized.
    static let vivaRecording: Color = .red

    /// AI-enhancement / sparkle purple. Used for transcription
    /// post-processing UI (sparkles icon, enhancement progress, etc.).
    /// Doubles as the first stop of `[Gradient.Stop].glowStyle`.
    static let vivaSparkle = Color(
        red: 188 / 255,
        green: 130 / 255,
        blue: 243 / 255
    )

    /// Error / destructive surfaces. See note on `vivaRecording` about
    /// intentional duplication of the underlying `.red` value.
    static let vivaError: Color = .red
}

#if DEBUG
#Preview("Brand tokens") {
    let tokens: [(name: String, color: Color)] = [
        ("vivaAccent", .vivaAccent),
        ("vivaRecording", .vivaRecording),
        ("vivaSparkle", .vivaSparkle),
        ("vivaError", .vivaError),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tokens, id: \.name) { token in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(token.color)
                        .frame(width: 48, height: 48)
                    Text(token.name)
                        .font(.body.monospaced())
                }
            }
        }
        .padding()
    }
}
#endif
