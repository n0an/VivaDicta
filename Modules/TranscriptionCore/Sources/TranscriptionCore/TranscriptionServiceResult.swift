// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

public struct TranscriptionServiceResult: Sendable {
    public let text: String
    public let isSpeakerAttributed: Bool
    /// Whisper language-identification probabilities keyed by language code
    /// (e.g. `["en": 0.72, "ru": 0.21]`). Populated only by the local
    /// WhisperKit backend when transcribing with automatic language
    /// detection; `nil` for cloud/Parakeet backends, which expose no such
    /// distribution.
    public let languageProbabilities: [String: Double]?

    public init(
        text: String,
        isSpeakerAttributed: Bool = false,
        languageProbabilities: [String: Double]? = nil
    ) {
        self.text = text
        self.isSpeakerAttributed = isSpeakerAttributed
        self.languageProbabilities = languageProbabilities
    }

    public static func plain(_ text: String) -> Self {
        Self(text: text)
    }

    public static func speakerAttributed(_ text: String) -> Self {
        Self(text: text, isSpeakerAttributed: true)
    }
}
