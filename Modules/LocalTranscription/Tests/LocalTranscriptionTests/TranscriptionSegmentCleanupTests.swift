//
//  TranscriptionSegmentCleanupTests.swift
//  LocalTranscriptionTests
//
//  Created by Anton Novoselov on 2026.09.06
//

import Foundation
import Testing
@testable import LocalTranscription

private struct StubSegment: SegmentSilenceSignal {
    var text: String
    var noSpeechProb: Float
    var avgLogprob: Float

    /// Real speech: the model is unsure it is silence.
    static func speech(_ text: String) -> StubSegment {
        StubSegment(text: text, noSpeechProb: 0.05, avgLogprob: -0.3)
    }

    /// Confident text over silence - the hallucination signature.
    static func hallucination(_ text: String) -> StubSegment {
        StubSegment(text: text, noSpeechProb: 0.92, avgLogprob: -0.2)
    }

    /// Quiet real speech: silent-looking, but the model is unsure of the words.
    static func quietSpeech(_ text: String) -> StubSegment {
        StubSegment(text: text, noSpeechProb: 0.85, avgLogprob: -1.4)
    }
}

struct TranscriptionSegmentCleanupTests {

    private func texts(_ segments: [StubSegment]) -> [String] {
        segments.map(\.text)
    }

    // MARK: - The case this exists for

    @Test func trailingThankYouOverSilence_isDropped() {
        let segments: [StubSegment] = [
            .speech("Please send the notes over."),
            .hallucination("Thank you.")
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(texts(sut) == ["Please send the notes over."])
    }

    @Test func trailingThankYouInRealSpeech_isKept() {
        let segments: [StubSegment] = [
            .speech("Please send the notes over."),
            .speech("Thank you.")
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(texts(sut) == texts(segments))
    }

    /// The discriminator is confidence, not loudness. Quiet speech trips the
    /// no-speech threshold but not the confidence one.
    @Test func quietRealSpeech_isKept() {
        let segments: [StubSegment] = [
            .speech("Here is the plan."),
            .quietSpeech("and maybe tomorrow")
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(texts(sut) == texts(segments))
    }

    // MARK: - Scope of the trim

    @Test func hallucinationInTheMiddle_isKept() {
        let segments: [StubSegment] = [
            .speech("First point."),
            .hallucination("Thank you."),
            .speech("Second point.")
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(texts(sut) == texts(segments), "only the tail is trimmed")
    }

    @Test func multipleTrailingHallucinations_allDropped() {
        let segments: [StubSegment] = [
            .speech("The actual dictation."),
            .hallucination("Thank you."),
            .hallucination("Субтитры добавил DimaTorzok")
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(texts(sut) == ["The actual dictation."])
    }

    @Test func allSilence_returnsEmpty() {
        let segments: [StubSegment] = [.hallucination("Thank you.")]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(sut.isEmpty, "an all-silence recording should come back empty")
    }

    @Test func emptyInput_returnsEmpty() {
        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations([StubSegment]())

        #expect(sut.isEmpty)
    }

    // MARK: - Blast-radius guards

    /// A long trailing segment is left alone even when both thresholds trip, so
    /// a mis-tuned threshold cannot eat a paragraph.
    @Test func longConfidentTrailingSegment_isKept() {
        let long = StubSegment(
            text: "This is a considerably longer closing thought that runs well past the word limit.",
            noSpeechProb: 0.92,
            avgLogprob: -0.2
        )
        let segments: [StubSegment] = [.speech("Opening."), long]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(texts(sut) == texts(segments))
    }

    @Test func punctuationOnlySegment_isNotTreatedAsHallucination() {
        let segment = StubSegment(text: " ... ", noSpeechProb: 0.92, avgLogprob: -0.2)

        #expect(TranscriptionSegmentCleanup.isLikelyHallucination(segment) == false)
    }

    // MARK: - Joining

    @Test func joinedText_collapsesSegmentBoundaryWhitespace() {
        let segments: [StubSegment] = [
            .speech(" Hello there. "),
            .speech("  How are you? ")
        ]

        let sut = TranscriptionSegmentCleanup.joinedText(segments)

        #expect(sut == "Hello there. How are you?")
    }

    @Test func joinedText_skipsEmptySegments() {
        let segments: [StubSegment] = [
            .speech("Only this."),
            .speech("   ")
        ]

        let sut = TranscriptionSegmentCleanup.joinedText(segments)

        #expect(sut == "Only this.")
    }

    // MARK: - The word-count boundary

    /// Until 3.10.1 these tests could not have been written honestly: WhisperKit
    /// was left at its default `skipSpecialTokens: false`, so every
    /// `segment.text` arrived with a leading `<|0.00|>`-style token followed by
    /// a space, while the trailing token merged onto the last word
    /// (`Tuesday.<|2.00|>`). The word filter admits anything containing a letter
    /// *or a number*, so that prefix counted, and every segment measured exactly
    /// one word longer than it read. `maximumWordCount = 6` therefore behaved as
    /// 5 against real audio. Verified against a real WhisperKit run: the raw
    /// segment split into 7 words where the clean text splits into 6.
    ///
    /// These pin the threshold at its designed value so it cannot drift back.

    @Test func hallucination_atExactlyMaximumWordCount_isDropped() {
        let text = "One two three four five six"
        #expect(text.split(separator: " ").count == TranscriptionSegmentCleanup.maximumWordCount)

        let segments: [StubSegment] = [
            .speech("Real dictated content that runs on for a while."),
            .hallucination(text)
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(sut.count == 1)
    }

    @Test func hallucination_oneWordOverMaximum_isKept() {
        let text = "One two three four five six seven"
        #expect(text.split(separator: " ").count == TranscriptionSegmentCleanup.maximumWordCount + 1)

        let segments: [StubSegment] = [
            .speech("Real dictated content that runs on for a while."),
            .hallucination(text)
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(sut.count == 2)
    }

    /// The regression guard: a six-word trailing segment must be judged on its
    /// clean text. If special tokens ever leak back in, the same segment counts
    /// seven and silently stops being trimmed.
    @Test func hallucination_sixWordsCarryingSpecialTokens_countsAsSeven() {
        let leaked = "<|0.00|> One two three four five six<|2.00|><|endoftext|>"

        #expect(TranscriptionSegmentCleanup.isLikelyHallucination(StubSegment.hallucination("One two three four five six")))
        #expect(TranscriptionSegmentCleanup.isLikelyHallucination(StubSegment.hallucination(leaked)) == false)
    }

    /// Quiet real speech at exactly the boundary stays, because the confidence
    /// gate rejects it before the word count is ever consulted.
    @Test func quietSpeech_atExactlyMaximumWordCount_isKept() {
        let segments: [StubSegment] = [
            .speech("Real dictated content that runs on for a while."),
            .quietSpeech("One two three four five six")
        ]

        let sut = TranscriptionSegmentCleanup.droppingTrailingHallucinations(segments)

        #expect(sut.count == 2)
    }
}
