//
//  AutoDeleteExemptions.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.30
//

import Foundation
import SwiftData
import os

/// Resolves which notes the user has shielded from the automatic cleanup sweeps.
///
/// A note is exempt when it carries at least one ``TranscriptionTag`` whose
/// ``TranscriptionTag/isExcludedFromAutoDelete`` flag is set. Auto-delete is meant for
/// short-lived, situational notes; tagging a long-form note (for example "Important")
/// opts it out without turning the feature off.
///
/// The tag ids are resolved once per sweep and matched in memory. `#Predicate` cannot
/// walk the ``TranscriptionTagAssignment`` junction into ``TranscriptionTag``, and the
/// tag table is tiny, so a single up-front fetch is cheaper than any predicate gymnastics.
struct AutoDeleteExemptions: Sendable {
    /// Ids of the tags marked as excluded from auto-delete.
    let protectedTagIDs: Set<UUID>

    /// `true` when nothing is protected, so callers can skip per-note filtering entirely.
    var isEmpty: Bool { protectedTagIDs.isEmpty }

    init(protectedTagIDs: Set<UUID> = []) {
        self.protectedTagIDs = protectedTagIDs
    }

    /// Loads the protected tag ids from the store.
    ///
    /// A fetch failure resolves to "nothing is protected" rather than throwing: a broken
    /// read must not silently disable cleanup, and the sweep logs its own errors.
    init(modelContext: ModelContext, logger: Logger? = nil) {
        let descriptor = FetchDescriptor<TranscriptionTag>(
            predicate: #Predicate { $0.isExcludedFromAutoDelete }
        )
        do {
            let tags = try modelContext.fetch(descriptor)
            self.init(protectedTagIDs: Set(tags.map(\.id)))
        } catch {
            logger?.logError("Auto-delete exemptions: Failed to fetch protected tags: \(error.localizedDescription)")
            self.init(protectedTagIDs: [])
        }
    }

    /// Whether the note carries at least one protected tag.
    func isExempt(_ transcription: Transcription) -> Bool {
        guard !protectedTagIDs.isEmpty else { return false }
        guard let assignments = transcription.tagAssignments else { return false }
        return assignments.contains { protectedTagIDs.contains($0.tagId) }
    }

    /// Splits notes into the ones a sweep may delete and the ones it must keep.
    func partition(_ transcriptions: [Transcription]) -> (deletable: [Transcription], exempt: [Transcription]) {
        guard !protectedTagIDs.isEmpty else { return (transcriptions, []) }
        var deletable: [Transcription] = []
        var exempt: [Transcription] = []
        for transcription in transcriptions {
            if isExempt(transcription) {
                exempt.append(transcription)
            } else {
                deletable.append(transcription)
            }
        }
        return (deletable, exempt)
    }
}
