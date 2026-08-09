// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import VivaDicta

/// Covers the Soniox realtime merge rule: final tokens accumulate, non-final
/// tokens are a full replacement set for the unstable tail. Getting this
/// backwards duplicates words as they firm up, which is invisible until you
/// read a real transcript - hence the direct tests.
@MainActor
struct RealtimeTranscriptAccumulatorTests {

    private func token(_ text: String, isFinal: Bool, kind: LiveTranslationToken.Kind = .original) -> LiveTranslationToken {
        LiveTranslationToken(id: UUID(), text: text, isFinal: isFinal, kind: kind)
    }

    @Test func finalTokensAccumulateAcrossBatches() {
        var sut = RealtimeTranscriptAccumulator()

        sut.ingest([token("Hello", isFinal: true)])
        sut.ingest([token(" world", isFinal: true)])

        #expect(sut.text == "Hello world")
    }

    @Test func interimTokensAreReplacedNotAppended() {
        var sut = RealtimeTranscriptAccumulator()

        sut.ingest([token(" rec", isFinal: false)])
        sut.ingest([token(" recog", isFinal: false)])
        sut.ingest([token(" recognition", isFinal: false)])

        #expect(sut.text == " recognition")
    }

    @Test func interimFirmingUpIntoFinalDoesNotDuplicate() {
        var sut = RealtimeTranscriptAccumulator()

        sut.ingest([token("Hello", isFinal: true), token(" wor", isFinal: false)])
        sut.ingest([token(" world", isFinal: true)])

        #expect(sut.text == "Hello world")
    }

    @Test func emptyBatchClearsTheInterimTail() {
        var sut = RealtimeTranscriptAccumulator()

        sut.ingest([token("Done", isFinal: true), token(" maybe", isFinal: false)])
        #expect(sut.text == "Done maybe")

        sut.ingest([])

        #expect(sut.text == "Done")
    }

    @Test func mixedBatchSplitsFinalsFromInterims() {
        var sut = RealtimeTranscriptAccumulator()

        sut.ingest([
            token("The", isFinal: true),
            token(" quick", isFinal: true),
            token(" bro", isFinal: false)
        ])

        #expect(sut.finalText == "The quick")
        #expect(sut.interimText == " bro")
        #expect(sut.text == "The quick bro")
    }

    @Test func translationTokensAreIgnored() {
        var sut = RealtimeTranscriptAccumulator()

        sut.ingest([
            token("Hello", isFinal: true),
            token("Привет", isFinal: true, kind: .translation)
        ])

        #expect(sut.text == "Hello")
    }

    @Test func startsEmpty() {
        let sut = RealtimeTranscriptAccumulator()

        #expect(sut.text.isEmpty)
    }
}
