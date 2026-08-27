// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Per-provider upload limits, checked before a request is built.
///
/// Without this, an over-long recording surfaced the vendor's raw HTTP 400 - a
/// wall of JSON that says nothing about the real problem or what to do instead.
/// Gemini is the tight one: its 20 MB cap covers the *whole request*, and the
/// audio is base64 in the JSON body, so the raw budget is about three quarters
/// of that.
///
/// Only documented limits are listed. Guessing one would block a transcription
/// that works today, which is worse than the raw 400 this replaces - so a
/// provider absent from this table is simply not checked.
public enum CloudTranscriptionLimits {
    /// Cloud services always receive 16 kHz mono 16-bit WAV, so bytes convert
    /// straight to seconds.
    private static let bytesPerSecond = 16_000.0 * 2.0

    /// Maximum raw audio bytes. Keyed by the provider's display name so this
    /// type does not have to depend on the app's provider enum.
    private static let maxAudioBytes: [String: Int] = [
        // 20 MB per request, and base64 inflates the payload by 4/3.
        "Gemini": 15_000_000,
        "OpenAI": 25_000_000,
        "Cohere": 25_000_000,
        // 25 MB on the free tier, 100 MB on dev. The lower bound is the safe one
        // because the app cannot tell which tier a key is on.
        "Groq": 25_000_000
    ]

    /// Providers with no documented size cap, offered as a way forward.
    private static let unlimitedProviderNames = ["Soniox", "Gladia", "AssemblyAI", "Deepgram"]

    /// Throws when `audioURL` is too large for the named provider.
    public static func check(audioURL: URL, providerDisplayName: String) throws {
        guard let limit = maxAudioBytes[providerDisplayName],
              let size = try? FileManager.default
                  .attributesOfItem(atPath: audioURL.path)[.size] as? Int,
              size > limit
        else { return }

        throw CloudTranscriptionError.audioTooLong(
            provider: providerDisplayName,
            limit: .seconds(Double(limit) / bytesPerSecond),
            actual: .seconds(Double(size) / bytesPerSecond),
            alternatives: unlimitedProviderNames
        )
    }
}
