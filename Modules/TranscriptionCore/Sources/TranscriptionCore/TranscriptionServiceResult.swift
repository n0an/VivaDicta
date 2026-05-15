// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

public struct TranscriptionServiceResult: Sendable {
    public let text: String
    public let isSpeakerAttributed: Bool

    public init(text: String, isSpeakerAttributed: Bool = false) {
        self.text = text
        self.isSpeakerAttributed = isSpeakerAttributed
    }

    public static func plain(_ text: String) -> Self {
        Self(text: text)
    }

    public static func speakerAttributed(_ text: String) -> Self {
        Self(text: text, isSpeakerAttributed: true)
    }
}
