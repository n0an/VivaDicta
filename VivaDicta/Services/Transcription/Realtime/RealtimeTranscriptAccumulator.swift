//
//  RealtimeTranscriptAccumulator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.08
//

import Foundation

/// Merges Soniox realtime token batches into a running transcript.
///
/// The subtlety this exists to contain: Soniox treats the non-final tokens in
/// each response as a **full replacement set** for the unstable tail, while
/// final tokens are append-only and never resent. Appending both would
/// duplicate every word as it firms up, so interims are rebuilt per batch and
/// only finals accumulate.
///
/// Pure value type with no actor or socket involvement, so the merge rule can
/// be tested directly. `nonisolated` because the session actor owns one and
/// mutates it off MainActor.
nonisolated struct RealtimeTranscriptAccumulator {
    private(set) var finalText = ""
    private(set) var interimText = ""

    /// Finals plus the current unstable tail. Soniox tokens carry their own
    /// leading spaces, so plain concatenation is correct - inserting
    /// separators here would double the spacing.
    var text: String {
        finalText + interimText
    }

    mutating func ingest(_ batch: [LiveTranslationToken]) {
        var interim = ""

        for token in batch {
            // Dictation never requests translation, but guard anyway so a stray
            // translation token can't be spliced into the transcript. Matched by
            // pattern rather than `==` because Kind's Equatable conformance is
            // MainActor-isolated and this is consumed from an actor.
            guard case .original = token.kind else { continue }

            if token.isFinal {
                finalText += token.text
            } else {
                interim += token.text
            }
        }

        // Replace, never append - including with an empty batch tail, which is
        // how Soniox signals that the interim region has firmed up entirely.
        interimText = interim
    }
}
