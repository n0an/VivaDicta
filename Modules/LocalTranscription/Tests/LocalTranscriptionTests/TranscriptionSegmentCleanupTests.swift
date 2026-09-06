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
}
