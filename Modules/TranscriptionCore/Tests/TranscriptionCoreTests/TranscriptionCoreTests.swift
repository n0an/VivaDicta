// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
@testable import TranscriptionCore

struct TranscriptionServiceResultTests {

    @Test func plainHelperBuildsNonSpeakerResult() {
        let result = TranscriptionServiceResult.plain("hello")
        #expect(result.text == "hello")
        #expect(result.isSpeakerAttributed == false)
    }

    @Test func speakerAttributedHelperFlagsResult() {
        let result = TranscriptionServiceResult.speakerAttributed("Alice: hi")
        #expect(result.text == "Alice: hi")
        #expect(result.isSpeakerAttributed == true)
    }
}

struct TranscriptionProgressInfoTests {

    @Test func clampsFractionAbove1() {
        let info = TranscriptionProgressInfo(stage: .transcribing, fractionCompleted: 1.5)
        #expect(info.fractionCompleted == 1.0)
    }

    @Test func clampsFractionBelow0() {
        let info = TranscriptionProgressInfo(stage: .transcribing, fractionCompleted: -0.3)
        #expect(info.fractionCompleted == 0.0)
    }

    @Test func preservesNilFraction() {
        let info = TranscriptionProgressInfo(stage: .preparingAudio)
        #expect(info.fractionCompleted == nil)
    }

    @Test func transcribingStageWithoutFractionReturnsNilDetail() {
        let info = TranscriptionProgressInfo(stage: .transcribing)
        #expect(info.detailText == nil)
    }

    @Test func nonTranscribingStageUsesStageDetailText() {
        let info = TranscriptionProgressInfo(stage: .detectingSpeech)
        #expect(info.detailText == "Detecting speech...")
    }
}
