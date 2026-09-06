// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import WhisperKit

/// The per-segment numbers the trailing-silence trim reasons about.
///
/// A protocol rather than the WhisperKit type directly so the rule can be
/// exercised without building a full `TranscriptionSegment` in tests.
protocol SegmentSilenceSignal {
    var text: String { get }
    var noSpeechProb: Float { get }
    var avgLogprob: Float { get }
}

extension TranscriptionSegment: SegmentSilenceSignal {}

/// Drops hallucinated segments that Whisper appends over trailing silence.
///
/// Whisper answers an empty window with something memorized from its training
/// data rather than with nothing: "Thank you." in English, the
/// "Субтитры ... DimaTorzok" family in Russian, and equivalents in other
/// languages. `TranscriptionOutputFilter` can strip the ones whose wording is
/// distinctive, but "Thank you." is indistinguishable from real speech *as
/// text* - people dictate it constantly - so it cannot be matched on the string.
///
/// The signal that does separate them is not in the words. A hallucination is
/// **confident text over silence**: high `noSpeechProb` paired with a high
/// `avgLogprob`. Genuinely quiet speech has the same high `noSpeechProb` but a
/// *low* `avgLogprob`, because the model is unsure of it. That pairing is also
/// exactly why these survive decoding at all - WhisperKit's `SegmentSeeker`
/// skips a silent segment unless `avgLogProb` rescues it, and a memorized
/// string always clears that bar.
enum TranscriptionSegmentCleanup {

    /// Above this, the segment covers what the model considers silence.
    static let noSpeechThreshold: Float = 0.6

    /// Above this, the model was confident about what it emitted. Real speech
    /// recorded quietly falls below it, which is what keeps it out of the trim.
    static let confidenceThreshold: Float = -0.5

    /// Hallucinated tails are short. A long segment is left alone even when it
    /// trips both thresholds, so the blast radius stays small when the numbers
    /// are wrong.
    static let maximumWordCount = 6

    /// Removes trailing segments that look hallucinated, stopping at the first
    /// one that does not.
    ///
    /// Trailing only, deliberately: this is a trailing-silence artifact, and
    /// scanning the middle would risk dropping a quiet aside between two
    /// sentences. Trimming everything is allowed - an all-silence recording
    /// should come back empty, and the caller's `hasMeaningfulContent` check
    /// handles that.
    static func droppingTrailingHallucinations<S: SegmentSilenceSignal>(_ segments: [S]) -> [S] {
        var endIndex = segments.endIndex
        while endIndex > segments.startIndex, isLikelyHallucination(segments[endIndex - 1]) {
            endIndex -= 1
        }
        return Array(segments[segments.startIndex..<endIndex])
    }

    static func isLikelyHallucination<S: SegmentSilenceSignal>(_ segment: S) -> Bool {
        guard segment.noSpeechProb > noSpeechThreshold else { return false }
        guard segment.avgLogprob > confidenceThreshold else { return false }

        let words = segment.text
            .split(whereSeparator: { $0.isWhitespace })
            .filter { $0.contains(where: \.isLetter) || $0.contains(where: \.isNumber) }
        return !words.isEmpty && words.count <= maximumWordCount
    }

    /// Applies the trim across a whole `[TranscriptionResult]`, peeling segments
    /// off the end of the flattened sequence so a hallucination that landed in
    /// its own result is caught too.
    ///
    /// Results left with no segments are dropped, and every surviving result's
    /// `text` is rebuilt so it cannot disagree with its segments.
    static func droppingTrailingHallucinations(
        in results: [TranscriptionResult]
    ) -> [TranscriptionResult] {
        let flattened = results.flatMap(\.segments)
        let kept = droppingTrailingHallucinations(flattened)
        var toDrop = flattened.count - kept.count
        guard toDrop > 0 else { return results }

        var trimmed = results
        for index in trimmed.indices.reversed() where toDrop > 0 {
            let removing = min(toDrop, trimmed[index].segments.count)
            trimmed[index].segments.removeLast(removing)
            trimmed[index].text = joinedText(of: trimmed[index].segments)
            toDrop -= removing
        }
        return trimmed.filter { !$0.segments.isEmpty }
    }

    /// Joins segment texts into a transcript, collapsing the whitespace Whisper
    /// leaves on segment boundaries.
    static func joinedText<S: SegmentSilenceSignal>(_ segments: [S]) -> String {
        joinedText(of: segments)
    }

    private static func joinedText<S: SegmentSilenceSignal>(of segments: [S]) -> String {
        segments
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
