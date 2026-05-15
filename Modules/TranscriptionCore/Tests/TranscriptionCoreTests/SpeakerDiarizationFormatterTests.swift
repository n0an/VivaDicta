// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import TranscriptionCore

struct SpeakerDiarizationFormatterTests {

    @Test func format_assignsStableAlphabeticLabelsInEncounterOrder() {
        let result = SpeakerDiarizationFormatter.format([
            SpeakerTurn(speakerID: "7", text: "Hello there."),
            SpeakerTurn(speakerID: "3", text: "Hi.")
        ])

        #expect(result == "Speaker A: Hello there.\n\nSpeaker B: Hi.")
    }

    @Test func format_mergesConsecutiveTurnsFromSameSpeaker() {
        let result = SpeakerDiarizationFormatter.format([
            SpeakerTurn(speakerID: "0", text: "Hello"),
            SpeakerTurn(speakerID: "0", text: "again"),
            SpeakerTurn(speakerID: "1", text: "Hi")
        ])

        #expect(result == "Speaker A: Hello again\n\nSpeaker B: Hi")
    }

    @Test func format_reusesPreviousSpeakerWhenProviderOmitsLabel() {
        let result = SpeakerDiarizationFormatter.format([
            SpeakerTurn(speakerID: "speaker-1", text: "Hello there."),
            SpeakerTurn(speakerID: nil, text: "Still me."),
            SpeakerTurn(speakerID: "speaker-2", text: "Now me.")
        ])

        #expect(result == "Speaker A: Hello there. Still me.\n\nSpeaker B: Now me.")
    }
}
