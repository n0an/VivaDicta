//
//  TranscriptionServiceResult.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

struct TranscriptionServiceResult: Sendable {
    let text: String
    let isSpeakerAttributed: Bool

    init(text: String, isSpeakerAttributed: Bool = false) {
        self.text = text
        self.isSpeakerAttributed = isSpeakerAttributed
    }

    static func plain(_ text: String) -> Self {
        Self(text: text)
    }

    static func speakerAttributed(_ text: String) -> Self {
        Self(text: text, isSpeakerAttributed: true)
    }
}
