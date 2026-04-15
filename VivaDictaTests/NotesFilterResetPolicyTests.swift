//
//  NotesFilterResetPolicyTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.04.15
//

import Testing
@testable import VivaDicta

struct NotesFilterResetPolicyTests {
    @Test func resetsToAllAfterDeletionRemovesLastFilteredResult() {
        let shouldReset = NotesFilterResetPolicy.shouldResetToAllAfterDeletion(
            hasActiveFilter: true,
            isSearching: false,
            oldTranscriptionCount: 4,
            newTranscriptionCount: 2,
            remainingFilteredCount: 0
        )

        #expect(shouldReset)
    }

    @Test func keepsFilterWhenMatchingNotesStillRemain() {
        let shouldReset = NotesFilterResetPolicy.shouldResetToAllAfterDeletion(
            hasActiveFilter: true,
            isSearching: false,
            oldTranscriptionCount: 4,
            newTranscriptionCount: 3,
            remainingFilteredCount: 1
        )

        #expect(!shouldReset)
    }

    @Test func keepsFilterWhenSearchIsActive() {
        let shouldReset = NotesFilterResetPolicy.shouldResetToAllAfterDeletion(
            hasActiveFilter: true,
            isSearching: true,
            oldTranscriptionCount: 4,
            newTranscriptionCount: 2,
            remainingFilteredCount: 0
        )

        #expect(!shouldReset)
    }

    @Test func keepsFilterWhenEverythingWasDeleted() {
        let shouldReset = NotesFilterResetPolicy.shouldResetToAllAfterDeletion(
            hasActiveFilter: true,
            isSearching: false,
            oldTranscriptionCount: 2,
            newTranscriptionCount: 0,
            remainingFilteredCount: 0
        )

        #expect(!shouldReset)
    }
}
